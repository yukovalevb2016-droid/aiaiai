import AVFoundation
import Speech
import SwiftUI

@MainActor
final class RecorderStore: ObservableObject {
    static let recordingsDirectory: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    @Published private(set) var recordings: [Recording] = []
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var liveTranscript = ""
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private var audioSink: AudioFileSink?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private var timer: Timer?
    private var activeID: UUID?
    private var startedAt: Date?

    private var indexURL: URL {
        Self.recordingsDirectory.appendingPathComponent("recordings.json")
    }

    init() {
        loadRecordings()
    }

    func startRecording() {
        guard !isRecording else { return }
        errorMessage = nil

        Task {
            let speechAllowed = await requestSpeechPermission()
            let microphoneAllowed = await requestMicrophonePermission()
            guard speechAllowed, microphoneAllowed else {
                errorMessage = "Разрешите доступ к микрофону и распознаванию речи в настройках iPhone."
                return
            }
            guard let recognizer, recognizer.isAvailable else {
                errorMessage = "Распознавание речи сейчас недоступно. Проверьте подключение и попробуйте ещё раз."
                return
            }
            beginRecording(using: recognizer)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        timer?.invalidate()
        timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        recognitionRequest?.endAudio()
        audioSink?.close()
        audioSink = nil
        isRecording = false
        saveActiveRecording()
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.audioURL)
        recordings.removeAll { $0.id == recording.id }
        persist()
    }

    func play(_ recording: Recording) {
        do {
            let player = try AVAudioPlayer(contentsOf: recording.audioURL)
            player.play()
            Playback.shared.player = player
        } catch {
            errorMessage = "Не удалось открыть аудиозапись."
        }
    }

    func updateTitle(_ title: String, for recording: Recording) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].title = title
        persist()
    }

    func updateExplanation(_ explanation: String, for recording: Recording) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].explanation = explanation
        persist()
    }

    private func beginRecording(using recognizer: SFSpeechRecognizer) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let id = UUID()
            let filename = "\(id.uuidString).m4a"
            let url = Self.recordingsDirectory.appendingPathComponent(filename)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            let sink = try AudioFileSink(url: url, settings: format.settings)
            audioSink = sink
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            recognitionRequest = request
            liveTranscript = ""
            activeID = id
            startedAt = Date()

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result {
                        self?.liveTranscript = result.bestTranscription.formattedString
                        self?.saveActiveRecording()
                    }
                    if error != nil, self?.isRecording == true {
                        self?.stopRecording()
                    }
                }
            }

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                sink.write(buffer)
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isRecording = true
            elapsed = 0
            recordings.insert(
                Recording(id: id, title: "", transcript: "", date: Date(), duration: 0, audioFilename: filename),
                at: 0
            )
            persist()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let startedAt = self.startedAt else { return }
                    self.elapsed = Date().timeIntervalSince(startedAt)
                }
            }
        } catch {
            cleanupAudio()
            errorMessage = "Не удалось начать запись. Проверьте доступ к микрофону."
        }
    }

    private func saveActiveRecording() {
        guard let id = activeID,
              let index = recordings.firstIndex(where: { $0.id == id }) else { return }
        recordings[index].transcript = liveTranscript
        recordings[index].duration = startedAt.map { Date().timeIntervalSince($0) } ?? elapsed
        persist()
    }

    private func cleanupAudio() {
        timer?.invalidate()
        timer = nil
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioSink?.close()
        audioSink = nil
        isRecording = false
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func loadRecordings() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Recording].self, from: data) else { return }
        recordings = decoded.filter { FileManager.default.fileExists(atPath: $0.audioURL.path) }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

private final class Playback {
    static let shared = Playback()
    var player: AVAudioPlayer?
}

private final class AudioFileSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?

    init(url: URL, settings: [String: Any]) throws {
        file = try AVAudioFile(forWriting: url, settings: settings)
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        try? file?.write(from: buffer)
    }

    func close() {
        lock.lock()
        file = nil
        lock.unlock()
    }
}

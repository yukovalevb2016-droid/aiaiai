import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var recorder: RecorderStore
    @State private var selectedRecording: Recording?

    private let ink = Color(red: 0.12, green: 0.18, blue: 0.20)
    private let teal = Color(red: 0.05, green: 0.48, blue: 0.42)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    recorderPanel
                    if let error = recorder.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                    if recorder.isRecording || !recorder.liveTranscript.isEmpty {
                        transcriptPanel
                    }
                    historySection
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.95))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedRecording) { recording in
                RecordingDetailView(recording: recording)
                    .environmentObject(recorder)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(teal)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .bold))
                Text("СЛУШАЙ")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 40)
            .foregroundStyle(teal)

            Text("Не упусти\nни слова.")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Запиши разговор — текст появится сам.")
                .font(.system(size: 16))
                .foregroundStyle(ink.opacity(0.62))
        }
    }

    private var recorderPanel: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(recorder.isRecording ? "Идёт запись" : "Готов к записи")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ink)
                    Text(recorder.isRecording ? "Русский · \(formattedTime(recorder.elapsed))" : "Речь распознаётся автоматически")
                        .font(.system(size: 13))
                        .foregroundStyle(ink.opacity(0.58))
                }
                Spacer()
                Circle()
                    .fill(recorder.isRecording ? Color.red : teal)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 3).padding(-4))
            }

            Button {
                recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(recorder.isRecording ? "Завершить запись" : "Начать запись")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(recorder.isRecording ? ink : teal, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("РАСШИФРОВКА")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(teal)
                Spacer()
                if recorder.isRecording {
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
            Text(recorder.liveTranscript.isEmpty ? "Слушаю… Говорите рядом с телефоном." : recorder.liveTranscript)
                .font(.system(size: 15))
                .lineSpacing(5)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(Color(red: 0.89, green: 0.94, blue: 0.91), in: RoundedRectangle(cornerRadius: 18))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("Записи")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                Spacer()
                Text("\(recorder.recordings.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink.opacity(0.5))
            }

            if recorder.recordings.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 19))
                        .foregroundStyle(teal)
                        .frame(width: 42, height: 42)
                        .background(teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Здесь будут ваши записи")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ink)
                        Text("Текст и аудио сохраняются на iPhone")
                            .font(.system(size: 12))
                            .foregroundStyle(ink.opacity(0.54))
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(recorder.recordings) { recording in
                    Button {
                        selectedRecording = recording
                    } label: {
                        RecordingRow(recording: recording)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            recorder.delete(recording)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct RecordingRow: View {
    let recording: Recording
    private let ink = Color(red: 0.12, green: 0.18, blue: 0.20)

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "waveform")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 0.05, green: 0.48, blue: 0.42))
                .frame(width: 44, height: 44)
                .background(Color(red: 0.89, green: 0.94, blue: 0.91), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(recording.date.formatted(date: .abbreviated, time: .shortened) + " · " + durationText(recording.duration))
                    .font(.system(size: 12))
                    .foregroundStyle(ink.opacity(0.55))
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink.opacity(0.3))
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func durationText(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct RecordingDetailView: View {
    @EnvironmentObject private var recorder: RecorderStore
    @Environment(\.dismiss) private var dismiss
    let recording: Recording
    @State private var shareItem: ShareItem?
    @State private var title: String
    @State private var explanation: String?
    @State private var explanationMode: String?
    @State private var isExplaining = false
    @State private var errorMessage: String?

    init(recording: Recording) {
        self.recording = recording
        _title = State(initialValue: recording.title)
        _explanation = State(initialValue: recording.explanation)
        _explanationMode = State(initialValue: recording.explanation == nil ? nil : "Сохранённый разбор")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Button {
                            recorder.play(recording)
                        } label: {
                            Label("Слушать аудио", systemImage: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(red: 0.05, green: 0.48, blue: 0.42), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        Button {
                            let text = explanation.map {
                                "ТЕМА И ОБЪЯСНЕНИЕ\n\($0)\n\nРАСШИФРОВКА\n\(recording.transcript)"
                            } ?? recording.transcript
                            shareItem = ShareItem(text: text)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 48, height: 48)
                                .background(Color(red: 0.94, green: 0.96, blue: 0.94), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.20))
                        }
                    }

                    Button {
                        requestExplanation()
                    } label: {
                        HStack(spacing: 9) {
                            if isExplaining {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text(isExplaining ? "Разбираю разговор…" : "Объяснить простыми словами")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(red: 0.12, green: 0.18, blue: 0.20), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .disabled(isExplaining || recording.transcript.isEmpty)

                    Text("Разбор выполняется на iPhone. API-ключ и интернет не нужны.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }

                    if let explanation {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("О ЧЁМ ЭТО")
                                    .tracking(0.8)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.05, green: 0.48, blue: 0.42))
                            Text(explanation)
                                .font(.system(size: 15))
                                .lineSpacing(5)
                                .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.20))
                                .textSelection(.enabled)
                            if let explanationMode {
                                Text(explanationMode)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color(red: 0.89, green: 0.94, blue: 0.91), in: RoundedRectangle(cornerRadius: 18))
                    }

                    TextField("Название записи", text: $title)
                        .font(.system(size: 15, weight: .medium))
                        .padding(14)
                        .background(Color(red: 0.96, green: 0.97, blue: 0.95), in: RoundedRectangle(cornerRadius: 12))
                        .onSubmit { recorder.updateTitle(title, for: recording) }
                        .onChange(of: title) { _, value in recorder.updateTitle(value, for: recording) }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("ТЕКСТ РАЗГОВОРА")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Color(red: 0.05, green: 0.48, blue: 0.42))
                        Text(recording.transcript.isEmpty ? "Речь не распозналась. Можно прослушать аудио и попробовать ещё раз." : recording.transcript)
                            .font(.system(size: 16))
                            .lineSpacing(6)
                            .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.20))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22)
            }
            .navigationTitle(recording.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.text])
                .presentationDetents([.medium, .large])
        }
    }

    private func requestExplanation() {
        errorMessage = nil
        isExplaining = true
        Task {
            do {
                let result = try await AIExplainer.explain(recording.transcript)
                explanation = result.text
                explanationMode = result.mode
                recorder.updateExplanation(result.text, for: recording)
            } catch {
                errorMessage = error.localizedDescription
            }
            isExplaining = false
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


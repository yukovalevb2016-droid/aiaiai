import Foundation

struct Recording: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var transcript: String
    var date: Date
    var duration: TimeInterval
    var audioFilename: String
    var explanation: String? = nil

    var audioURL: URL {
        RecorderStore.recordingsDirectory.appendingPathComponent(audioFilename)
    }

    var displayTitle: String {
        title.isEmpty ? "Запись от \(date.formatted(date: .omitted, time: .shortened))" : title
    }
}

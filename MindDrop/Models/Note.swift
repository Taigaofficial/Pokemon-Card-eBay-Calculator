import Foundation
import SwiftData

/// A single captured thought: the raw transcript plus the structured
/// fields extracted by the LLM.
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var summary: String
    var transcript: String
    var category: String
    var actionItems: [String]
    /// File name (not full path) of the recorded M4A inside the app's
    /// Documents directory, so the original audio can be replayed.
    var audioFileName: String?
    /// True while the note is still waiting on transcription/extraction
    /// (e.g. captured offline or a network failure occurred).
    var isProcessing: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        summary: String,
        transcript: String,
        category: String,
        actionItems: [String] = [],
        audioFileName: String? = nil,
        isProcessing: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.summary = summary
        self.transcript = transcript
        self.category = category
        self.actionItems = actionItems
        self.audioFileName = audioFileName
        self.isProcessing = isProcessing
    }
}

extension Note {
    var audioFileURL: URL? {
        guard let audioFileName else { return nil }
        return URL.documentsDirectory.appending(path: audioFileName)
    }
}

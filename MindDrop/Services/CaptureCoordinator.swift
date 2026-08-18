import Foundation
import SwiftData
import Observation

/// Orchestrates a capture end-to-end: record → transcribe → extract → persist.
/// Shared between the UI and the App Intent so the Action Button and the
/// in-app record button drive the exact same pipeline.
@MainActor
@Observable
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    private(set) var isProcessing = false
    private(set) var lastError: String?

    private var container: ModelContainer?

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    var isRecording: Bool { AudioService.shared.isRecording }

    /// Toggles recording. Returns `true` if a recording was started,
    /// `false` if one was stopped (and processing kicked off).
    @discardableResult
    func toggleCapture() async throws -> Bool {
        if AudioService.shared.isRecording {
            await finishCapture()
            return false
        } else {
            lastError = nil
            PlaybackService.shared.stop()
            try await AudioService.shared.startRecording()
            return true
        }
    }

    /// Stops the recorder and runs the API pipeline, saving the result.
    func finishCapture() async {
        guard let audioURL = AudioService.shared.stopRecording() else { return }
        guard let container else { return }

        isProcessing = true
        defer { isProcessing = false }

        let context = container.mainContext

        do {
            let (transcript, extracted) = try await APIService.shared.process(audioFileURL: audioURL)
            let note = Note(
                title: extracted.title,
                summary: extracted.summary,
                transcript: transcript,
                category: extracted.category,
                actionItems: extracted.actionItems,
                audioFileName: audioURL.lastPathComponent
            )
            context.insert(note)
            try context.save()
        } catch {
            // Keep the audio and store a placeholder note so the capture
            // is never lost — the user can retry processing later.
            lastError = error.localizedDescription
            let note = Note(
                title: "Unprocessed thought",
                summary: "This recording hasn't been transcribed yet. Tap to retry.",
                transcript: "",
                category: "Other",
                audioFileName: audioURL.lastPathComponent,
                isProcessing: true
            )
            context.insert(note)
            try? context.save()
        }
    }

    /// Re-runs the API pipeline for a note whose processing previously failed.
    func retryProcessing(note: Note) async {
        guard let audioURL = note.audioFileURL, let container else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let (transcript, extracted) = try await APIService.shared.process(audioFileURL: audioURL)
            note.title = extracted.title
            note.summary = extracted.summary
            note.transcript = transcript
            note.category = extracted.category
            note.actionItems = extracted.actionItems
            note.isProcessing = false
            try container.mainContext.save()
        } catch {
            lastError = error.localizedDescription
        }
    }
}

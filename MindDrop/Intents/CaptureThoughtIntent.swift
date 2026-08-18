import AppIntents
import SwiftData

/// Starts or stops a thought capture. Because it's an `AppIntent` exposed
/// through `MindDropShortcuts`, it can be assigned to the Action Button
/// (Settings → Action Button → Shortcut → MindDrop → Capture Thought).
struct CaptureThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Thought"
    static let description = IntentDescription(
        "Starts recording a voice thought, or stops and processes the current recording.",
        categoryName: "Capture"
    )

    // Recording needs the app process live in the foreground so the
    // microphone session stays active while the user speaks.
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // When launched via the Action Button before the app has ever run,
        // the App struct's init has already executed by this point, so the
        // coordinator is configured.
        let started = try await CaptureCoordinator.shared.toggleCapture()
        return .result(
            dialog: started
                ? "Recording. Press again to stop."
                : "Got it — processing your thought."
        )
    }
}

/// Publishes the intent to Shortcuts, Spotlight, and the Action Button picker.
struct MindDropShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureThoughtIntent(),
            phrases: [
                "Capture a thought in \(.applicationName)",
                "Start recording in \(.applicationName)",
                "\(.applicationName) capture",
            ],
            shortTitle: "Capture Thought",
            systemImageName: "waveform.circle.fill"
        )
    }
}

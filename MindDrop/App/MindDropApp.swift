import SwiftUI
import SwiftData

@main
struct MindDropApp: App {
    /// Shared model container backing SwiftData persistence for `Note`.
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Note.self)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
        // Hand the container to the capture pipeline so the App Intent
        // (which may run before any view exists) can persist notes too.
        CaptureCoordinator.shared.configure(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}

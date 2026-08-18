import SwiftUI
import SwiftData

/// Main screen: past notes grouped by date, a search bar, and the record button.
struct NotesListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var expandedNoteID: UUID?
    @State private var showingSettings = false
    @State private var captureError: String?

    private var audioService = AudioService.shared
    private var coordinator = CaptureCoordinator.shared

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
                || $0.transcript.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Notes bucketed by calendar day, newest day first.
    private var groupedNotes: [(day: Date, notes: [Note])] {
        Dictionary(grouping: filteredNotes) {
            Calendar.current.startOfDay(for: $0.createdAt)
        }
        .sorted { $0.key > $1.key }
        .map { (day: $0.key, notes: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                if notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }

                recordButton
                    .padding(.bottom, 24)
            }
            .navigationTitle("MindDrop")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search thoughts")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .preferredColorScheme(.dark)
            }
            .alert(
                "Capture failed",
                isPresented: .init(
                    get: { captureError != nil },
                    set: { if !$0 { captureError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(captureError ?? "")
            }
        }
        .tint(.mint)
    }

    // MARK: - Subviews

    private var notesList: some View {
        List {
            ForEach(groupedNotes, id: \.day) { group in
                Section {
                    ForEach(group.notes) { note in
                        NoteCardView(
                            note: note,
                            isExpanded: expandedNoteID == note.id
                        ) {
                            withAnimation(.snappy) {
                                expandedNoteID = expandedNoteID == note.id ? nil : note.id
                            }
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground).opacity(0.35))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { offsets in
                        delete(offsets, in: group.notes)
                    }
                } header: {
                    Text(group.day, format: .dateTime.weekday(.wide).month().day())
                        .font(.caption.smallCaps())
                        .foregroundStyle(.secondary)
                }
            }
            // Keep the last card clear of the floating record button.
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No thoughts yet", systemImage: "brain.head.profile")
        } description: {
            Text("Tap the mic — or press your Action Button — to capture your first thought.")
        }
    }

    private var recordButton: some View {
        Button {
            Task {
                do {
                    try await coordinator.toggleCapture()
                } catch {
                    captureError = error.localizedDescription
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(audioService.isRecording ? Color.red : Color.mint)
                    .frame(width: 68, height: 68)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                    .scaleEffect(
                        audioService.isRecording
                            ? 1 + CGFloat(audioService.inputLevel) * 0.25
                            : 1
                    )
                    .animation(.linear(duration: 0.1), value: audioService.inputLevel)

                if coordinator.isProcessing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: audioService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.black)
                }
            }
        }
        .accessibilityLabel(audioService.isRecording ? "Stop recording" : "Start recording")
        .disabled(coordinator.isProcessing)
    }

    // MARK: - Actions

    private func delete(_ offsets: IndexSet, in groupNotes: [Note]) {
        for index in offsets {
            let note = groupNotes[index]
            if let url = note.audioFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(note)
        }
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: Note.self, inMemory: true)
        .preferredColorScheme(.dark)
}

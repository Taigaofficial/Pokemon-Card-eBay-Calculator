import SwiftUI
import SwiftData

/// How the note list is organized. Notes inside every group stay sorted
/// by time (newest first).
enum GroupingMode: String, CaseIterable, Identifiable {
    case day
    case topic
    case folder

    var id: String { rawValue }
    var label: String {
        switch self {
        case .day: "Day"
        case .topic: "Topic"
        case .folder: "Folder"
        }
    }
    var icon: String {
        switch self {
        case .day: "calendar"
        case .topic: "tag"
        case .folder: "folder"
        }
    }
}

/// Main screen: past notes grouped by day/topic/folder, search, record button.
struct NotesListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("grouping_mode") private var groupingModeRaw = GroupingMode.day.rawValue
    @State private var searchText = ""
    @State private var expandedNoteID: UUID?
    @State private var showingSettings = false
    @State private var captureError: String?
    @State private var newFolderName = ""
    @State private var noteAwaitingNewFolder: Note?

    private var audioService = AudioService.shared
    private var coordinator = CaptureCoordinator.shared
    private let theme = Theme.current

    private var groupingMode: GroupingMode {
        GroupingMode(rawValue: groupingModeRaw) ?? .day
    }

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
                || $0.transcript.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText)
                || ($0.folder?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// Notes bucketed according to the selected grouping mode.
    private var groupedNotes: [(id: String, title: String, notes: [Note])] {
        switch groupingMode {
        case .day:
            return Dictionary(grouping: filteredNotes) {
                Calendar.current.startOfDay(for: $0.createdAt)
            }
            .sorted { $0.key > $1.key }
            .map { day, notes in
                (
                    id: day.timeIntervalSince1970.description,
                    title: day.formatted(.dateTime.weekday(.wide).month().day()),
                    notes: notes
                )
            }
        case .topic:
            return Dictionary(grouping: filteredNotes, by: \.category)
                .sorted { $0.key < $1.key }
                .map { (id: "topic-\($0.key)", title: $0.key, notes: $0.value) }
        case .folder:
            let groups = Dictionary(grouping: filteredNotes) { $0.folder?.name ?? "" }
            let named = groups
                .filter { !$0.key.isEmpty }
                .sorted { $0.key < $1.key }
                .map { (id: "folder-\($0.key)", title: $0.key, notes: $0.value) }
            // Unfiled notes go last so real folders stay prominent.
            if let unfiled = groups[""] {
                return named + [(id: "folder-unfiled", title: "Unfiled", notes: unfiled)]
            }
            return named
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                backgroundView

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
                ToolbarItem(placement: .topBarLeading) {
                    groupingMenu
                }
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
            .alert(
                "New Folder",
                isPresented: .init(
                    get: { noteAwaitingNewFolder != nil },
                    set: { if !$0 { noteAwaitingNewFolder = nil } }
                )
            ) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") { createFolderForPendingNote() }
                Button("Cancel", role: .cancel) { newFolderName = "" }
            }
        }
        .tint(theme.accent)
    }

    // MARK: - Subviews

    /// Near-black base with ambient glow washes (violet top-left, amber
    /// bottom-right). Themes with `.clear` glows render as a flat color.
    private var backgroundView: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            RadialGradient(
                colors: [theme.glowPrimary.opacity(0.34), .clear],
                center: UnitPoint(x: -0.1, y: -0.05),
                startRadius: 0,
                endRadius: 440
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [theme.glowSecondary.opacity(0.26), .clear],
                center: UnitPoint(x: 1.08, y: 0.82),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }

    private var groupingMenu: some View {
        Menu {
            Picker("Group by", selection: $groupingModeRaw) {
                ForEach(GroupingMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode.rawValue)
                }
            }
        } label: {
            Label("Group by", systemImage: groupingMode.icon)
        }
    }

    private var notesList: some View {
        List {
            ForEach(groupedNotes, id: \.id) { group in
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
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .contextMenu { contextMenu(for: note) }
                    }
                    .onDelete { offsets in
                        delete(offsets, in: group.notes)
                    }
                } header: {
                    Text(group.title)
                        .font(.caption.smallCaps().bold())
                        .foregroundStyle(theme.metaText)
                        .padding(.leading, 4)
                }
            }
            // Keep the last card clear of the floating record button.
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func contextMenu(for note: Note) -> some View {
        Menu {
            ForEach(folders) { folder in
                Button {
                    note.folder = folder
                } label: {
                    if note.folder == folder {
                        Label(folder.name, systemImage: "checkmark")
                    } else {
                        Text(folder.name)
                    }
                }
            }
            if !folders.isEmpty {
                Divider()
            }
            Button("New Folder…", systemImage: "folder.badge.plus") {
                noteAwaitingNewFolder = note
            }
            if note.folder != nil {
                Button("Remove from Folder", role: .destructive) {
                    note.folder = nil
                }
            }
        } label: {
            Label("Move to Folder", systemImage: "folder")
        }
        Button(role: .destructive) {
            delete(note)
        } label: {
            Label("Delete", systemImage: "trash")
        }
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
                    .fill(audioService.isRecording ? theme.recording : theme.accent)
                    .frame(width: 68, height: 68)
                    .shadow(
                        color: (audioService.isRecording ? theme.recording : theme.accent).opacity(0.45),
                        radius: 16, y: 2
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
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

    private func createFolderForPendingNote() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            newFolderName = ""
            noteAwaitingNewFolder = nil
        }
        guard !name.isEmpty, let note = noteAwaitingNewFolder else { return }

        if let existing = folders.first(where: { $0.name == name }) {
            note.folder = existing
        } else {
            let folder = Folder(name: name)
            modelContext.insert(folder)
            note.folder = folder
        }
    }

    private func delete(_ offsets: IndexSet, in groupNotes: [Note]) {
        for index in offsets {
            delete(groupNotes[index])
        }
    }

    private func delete(_ note: Note) {
        if let url = note.audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(note)
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: [Note.self, Folder.self], inMemory: true)
        .preferredColorScheme(.dark)
}

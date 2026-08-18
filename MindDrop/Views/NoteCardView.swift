import SwiftUI

/// A collapsible card for one note. Collapsed it shows title, category and
/// time; expanded it reveals the summary, action items, and raw transcript.
struct NoteCardView: View {
    let note: Note
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    CategoryBadge(category: note.category)
                    Text(note.createdAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if note.isProcessing {
                        Label("Needs processing", systemImage: "arrow.trianglehead.clockwise")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.summary)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.9))

            if !note.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Action Items")
                        .font(.caption.smallCaps().bold())
                        .foregroundStyle(.mint)
                    ForEach(note.actionItems, id: \.self) { item in
                        Label(item, systemImage: "circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !note.transcript.isEmpty {
                DisclosureGroup {
                    Text(note.transcript)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } label: {
                    Text("Raw transcript")
                        .font(.caption.smallCaps())
                        .foregroundStyle(.tertiary)
                }
            }

            if note.isProcessing {
                Button {
                    Task { await CaptureCoordinator.shared.retryProcessing(note: note) }
                } label: {
                    Label("Retry processing", systemImage: "arrow.trianglehead.clockwise")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }
}

/// Small colored pill showing the note's category.
struct CategoryBadge: View {
    let category: String

    private var color: Color {
        switch category {
        case "Idea": .yellow
        case "Task": .mint
        case "Journal": .purple
        case "Work": .blue
        case "Personal": .pink
        default: .gray
        }
    }

    var body: some View {
        Text(category)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

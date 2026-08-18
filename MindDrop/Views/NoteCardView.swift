import SwiftUI

/// A collapsible card for one note. Collapsed it shows title, category and
/// time; expanded it reveals the summary, action items, playback/share
/// controls, and the raw transcript.
struct NoteCardView: View {
    let note: Note
    let isExpanded: Bool
    let onTap: () -> Void

    private let theme = Theme.current
    private var playback = PlaybackService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
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
                        .foregroundStyle(theme.metaText)
                    if let folder = note.folder {
                        Label(folder.name, systemImage: "folder")
                            .font(.caption)
                            .foregroundStyle(theme.metaText)
                    }
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
                        .foregroundStyle(theme.actionHeader)
                    ForEach(note.actionItems, id: \.self) { item in
                        Label {
                            Text(item)
                        } icon: {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(theme.checkmark)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                if note.audioFileURL != nil {
                    Button {
                        playback.toggle(note)
                    } label: {
                        Label(
                            playback.isPlaying(note) ? "Stop" : "Play recording",
                            systemImage: playback.isPlaying(note) ? "stop.fill" : "play.fill"
                        )
                        .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.accent)
                }
                ShareLink(item: note.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(theme.metaText)
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
                        .foregroundStyle(theme.metaText.opacity(0.8))
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
        Theme.current.color(forCategory: category)
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

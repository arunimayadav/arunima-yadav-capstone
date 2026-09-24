import SwiftUI
import AppKit

/// The full record view — skills/metadata-enrichment.md describes assembling and
/// writing a complete record onto every node (location, category, tags, summary,
/// confidence, status, timestamps), but until now nothing in the UI ever showed
/// that complete record back to the user; search only ever surfaced a filename,
/// tag, and a two-line summary. This is that missing surface: every field the
/// skill says a node's record should carry, shown in one place, opened from a
/// result card.
struct NodeDetailView: View {
    let node: Node

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Divider()

                field("Summary") {
                    Text(node.summary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                }

                field("Location") {
                    HStack(spacing: 8) {
                        Text(node.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ArchivistPalette.secondaryText)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    field("Category") {
                        TagPill.forFinderTag(node.category)
                    }
                    field("Status") {
                        Text(statusLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ArchivistPalette.secondaryText)
                    }
                    field("Confidence") {
                        Text("\(Int(node.confidence * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ArchivistPalette.secondaryText)
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    field("Doc type") {
                        Text(node.docType.isEmpty ? "—" : node.docType)
                            .font(.system(size: 12))
                            .foregroundStyle(ArchivistPalette.secondaryText)
                    }
                    field("Ownership") {
                        Text(node.ownership.isEmpty ? "—" : node.ownership.capitalized)
                            .font(.system(size: 12))
                            .foregroundStyle(ArchivistPalette.secondaryText)
                    }
                }

                field("Created") {
                    Text(Self.timestampFormatter.string(from: node.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                }

                field("Last updated") {
                    Text(Self.timestampFormatter.string(from: node.updatedAt))
                        .font(.system(size: 12))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                }

                field("Classified by") {
                    Text(node.providerUsed)
                        .font(.system(size: 12))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(16)
        }
    }

    private var statusLabel: String {
        switch node.status {
        case .indexed: return "Indexed"
        case .pendingReview: return "Pending review"
        case .duplicateSkipped: return "Duplicate (skipped)"
        case .rejected: return "Rejected"
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            let glyph = FileTypeGlyph.symbol(for: node.filename)
            FileThumbnailView(path: node.path, glyphName: glyph.name, glyphTint: glyph.tint, maxWidth: 64, maxHeight: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.filename)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(node.title.isEmpty ? node.filename : node.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.4)
            content()
        }
    }
}

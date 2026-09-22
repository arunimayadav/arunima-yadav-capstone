import SwiftUI
import AppKit

/// Low-confidence files land here instead of being silently guessed at —
/// plan.md section 5 step 8 / section 8.
struct ReviewView: View {
    let store: GraphStore
    @State private var items: [Node] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    instruction: "Nothing needs review — low-confidence files will show up here.",
                    examples: [],
                    onSelectExample: { _ in }
                )
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(items) { node in
                            reviewCard(node)
                        }
                    }
                }
            }
        }
        .padding(14)
        .onAppear { items = store.pendingReview() }
    }

    private func reviewCard(_ node: Node) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                let glyph = FileTypeGlyph.symbol(for: node.filename)
                Image(systemName: glyph.name)
                    .font(.system(size: 15))
                    .foregroundStyle(glyph.tint)
                    .frame(width: 30, height: 30)
                    .background(glyph.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(node.filename)
                            .font(ArchivistType.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        TagPill(text: node.category, tint: .orange)
                    }
                    Text(node.summary)
                        .font(ArchivistType.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Text("\(Int(node.confidence * 100))%")
                    .font(ArchivistType.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
            } label: {
                Text("Reveal in Finder")
                    .font(ArchivistType.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

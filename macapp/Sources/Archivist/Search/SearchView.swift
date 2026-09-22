import SwiftUI
import AppKit

/// Graph-based search: query the GraphStore, show the single closest match plus
/// what it's connected to (same_tag/same_category/similar_content) — plan.md
/// section 5/6. Shows only one result (the closest), not a ranked list.
struct SearchView: View {
    let store: GraphStore
    @State private var query: String = ""
    @State private var results: [Node] = []
    @State private var hasSearched = false
    @State private var showRelated = false

    private let examples = ["resume", "invoice", "lecture notes", "receipt"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField

            if results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    instruction: hasSearched
                        ? "No matches for “\(query)”. Try another word from the file's name, content, or tag."
                        : "Search by filename, content, or tag.",
                    examples: examples,
                    onSelectExample: { example in
                        query = example
                        runSearch()
                    }
                )
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(results) { node in
                            SearchResultCard(
                                node: node,
                                showRelated: showRelated,
                                related: showRelated ? store.connectedNodes(to: node.id) : [],
                                onToggleRelated: { showRelated.toggle() },
                                onOpen: {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
    }

    /// A native-feeling search field: leading glass icon, plain (chromeless) text
    /// field, trailing clear button — matching macOS's system search fields
    /// (Mail, Notes sidebar) rather than a generic bordered `TextField`.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search your files", text: $query, onCommit: runSearch)
                .textFieldStyle(.plain)
                .font(ArchivistType.body)
                .onChange(of: query) { _ in runSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                    runSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func runSearch() {
        results = store.search(query: query, limit: 1)
        hasSearched = !query.isEmpty
        showRelated = false
    }
}

/// A single search result: file-type icon, filename + category pill, a short
/// description, and the date tucked in the top-right corner — clicking the card
/// reveals it in Finder; "Show related" is a separate, explicit action.
private struct SearchResultCard: View {
    let node: Node
    let showRelated: Bool
    let related: [Node]
    let onToggleRelated: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        TagPill(text: node.category)
                    }
                    Text(node.summary)
                        .font(ArchivistType.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Text(RelativeDate.string(from: node.createdAt))
                    .font(ArchivistType.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if showRelated {
                Divider().opacity(0.5)
                if related.isEmpty {
                    Text("No related files yet.")
                        .font(ArchivistType.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(related.prefix(4)) { r in
                            Text(r.filename)
                                .font(ArchivistType.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Button(action: onToggleRelated) {
                Text(showRelated ? "Hide related" : "Show related")
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

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
    @State private var isClearHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField

            if results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    instruction: hasSearched
                        ? "No matches for “\(query)”. Try another word from the file's name, content, or tag."
                        : "Search by filename, content, or tag."
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
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    /// A native-feeling, "inset" search field — matching macOS's system search
    /// fields (Mail, Notes sidebar) rather than a generic bordered `TextField`.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(ArchivistPalette.placeholderText)
            TextField("", text: $query, prompt: Text("Search your files").foregroundColor(ArchivistPalette.placeholderText))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .onSubmit(runSearch)
                .onChange(of: query) { _ in runSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                    runSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ArchivistPalette.placeholderText.opacity(isClearHovered ? 1 : 0.7))
                }
                .buttonStyle(.plain)
                .onHover { isClearHovered = $0 }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(ArchivistPalette.searchFieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    @State private var isRelatedLinkHovered = false

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
            .hoverHighlight(cornerRadius: 8)

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
                    .foregroundStyle(Color.accentColor.opacity(isRelatedLinkHovered ? 0.75 : 1))
                    .underline(isRelatedLinkHovered)
            }
            .buttonStyle(.plain)
            .onHover { isRelatedLinkHovered = $0 }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

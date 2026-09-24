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
                // Only the "no matches" case gets text — that's feedback about
                // what just happened, not generic how-to-use instruction. Before
                // any search, the field's own placeholder already says how to use
                // this screen, so nothing else here repeats it.
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    instruction: hasSearched
                        ? "No matches for “\(query)”. Try another word from the file's name, content, or tag."
                        : nil
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(results) { node in
                            SearchResultCard(node: node)
                            // "Show related" lives below the card, not inside its
                            // background/padding — a separate, secondary action,
                            // not part of the card itself.
                            RelatedFilesSection(
                                isExpanded: showRelated,
                                related: showRelated ? store.connectedNodes(to: node.id) : [],
                                onToggle: { showRelated.toggle() }
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
            TextField("", text: $query, prompt: Text("Search your files by filename, content, or tag").foregroundColor(ArchivistPalette.placeholderText))
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

/// A single search result: a real thumbnail of the file's first page/content
/// (not just a type glyph), filename + the tag actually assigned to it, a short
/// description, and the date tucked in the card's corner. Tapping anywhere on the
/// card opens the full record (skills/metadata-enrichment.md) — location, status,
/// confidence, timestamps, full summary — with Reveal in Finder available there,
/// rather than the card itself trying to juggle two different tap targets for
/// two different actions.
private struct SearchResultCard: View {
    let node: Node

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                let glyph = FileTypeGlyph.symbol(for: node.filename)
                FileThumbnailView(path: node.path, glyphName: glyph.name, glyphTint: glyph.tint, maxWidth: 56, maxHeight: 56)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(node.filename)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        // The tag actually assigned to the file (same as its
                        // Finder tag), not the broader classification bucket —
                        // falls back to category only if no topic tag exists.
                        TagPill.forFinderTag(node.tags.first ?? node.category)
                            .layoutPriority(1) // never truncated/compressed — filename gives way first

                        // Flexible, not a fixed trailing padding guess: the gap
                        // between the pill and the date always fills whatever
                        // space is left, so a short filename+tag doesn't crowd
                        // the date and a long one doesn't overlap it either —
                        // the visual distance from the pill to the date is
                        // "whatever's left of the row", never a hardcoded number.
                        Spacer(minLength: 8)

                        Text(RelativeDate.string(from: node.createdAt))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(ArchivistPalette.tertiaryText)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }

                    Text(node.summary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                        .lineLimit(2)
                }
            }
            .hoverHighlight(cornerRadius: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading) // matches the search bar's width exactly
        .background(ArchivistPalette.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .popover(isPresented: $showDetail) {
            NodeDetailView(node: node)
                .frame(width: 320, height: 420)
        }
    }
}

/// "Show related" and the connected-files list, rendered below the card rather
/// than inside its background/padding — a secondary, optional action, not part
/// of the card itself.
private struct RelatedFilesSection: View {
    let isExpanded: Bool
    let related: [Node]
    let onToggle: () -> Void

    @State private var isLinkHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onToggle) {
                Text(isExpanded ? "Hide related" : "Show related")
                    .font(ArchivistType.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor.opacity(isLinkHovered ? 0.75 : 1))
                    .underline(isLinkHovered)
            }
            .buttonStyle(.plain)
            .onHover { isLinkHovered = $0 }
            .padding(.horizontal, 4)

            if isExpanded {
                if related.isEmpty {
                    Text("No related files yet.")
                        .font(ArchivistType.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(related.prefix(4)) { r in
                            Text(r.filename)
                                .font(ArchivistType.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

import SwiftUI
import AppKit

/// Graph-based search: query the GraphStore, show every sufficiently-relevant
/// match ranked best-first, each with what it's connected to (same_tag/
/// same_category/similar_content) — plan.md section 5/6.
struct SearchView: View {
    let store: GraphStore
    @State private var query: String = ""
    @State private var results: [Node] = []
    @State private var hasSearched = false
    @State private var isClearHovered = false

    /// Capped, not unlimited — `GraphStore.search` already requires a minimum
    /// relevance score (see its `minimumScore` guard) before a node counts as a
    /// match at all, so this is purely "how many of the genuinely relevant hits
    /// to show," not a substitute for that relevance filter. Was hardcoded to 1,
    /// which is why a query matching two files (e.g. two "Academic…" files for
    /// "aca") only ever rendered one card — this raises it enough to show real
    /// matches without turning the tab into an unbounded list.
    private static let resultLimit = 8

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
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(results) { node in
                            SearchResultCard(node: node)
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    /// A native-feeling, "inset" search field — matching macOS's system search
    /// fields (Mail, Notes sidebar) rather than a generic bordered `TextField`.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(ArchivistPalette.secondaryText.opacity(0.88))
            TextField("", text: $query, prompt: Text("Search your files by filename, content, or tag").foregroundColor(ArchivistPalette.placeholderText))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(ArchivistPalette.primaryText)
                .onSubmit(runSearch)
                .onChange(of: query) { _ in runSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                    runSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(StatefulIconButtonStyle(
                    isHovered: isClearHovered,
                    hitSize: 28,
                    normalColor: ArchivistPalette.placeholderText,
                    hoverColor: ArchivistPalette.secondaryText,
                    pressedColor: Color(hex: "4A4A4D")
                ))
                .onHover { isClearHovered = $0 }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, query.isEmpty ? 10 : 8)
        .frame(height: 32)
        .background(ArchivistPalette.searchFieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    private func runSearch() {
        results = store.search(query: query, limit: Self.resultLimit)
        hasSearched = !query.isEmpty
    }
}

/// A single search result: a real thumbnail of the file's first page/content
/// (not just a type glyph), filename + the tag actually assigned to it, a short
/// description, and the date tucked in the card's corner. Two distinct tap
/// targets, not one: tapping the card itself reveals the file in Finder —
/// the fast, common action — while tapping the summary text specifically
/// expands it in place (skills/metadata-enrichment.md) to show the full
/// summary plus location and timestamps. The rest of that skill's record
/// (status, confidence, doc type, ownership) is still computed and stored on
/// the node as always, it's just not surfaced here since it isn't useful to a
/// user, and the tag/category is already visible up top.
private struct SearchResultCard: View {
    let node: Node

    @State private var isExpanded = false
    @State private var isCardHovered = false

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The header row's height is fixed regardless of `isExpanded` — the
            // summary here always caps at 2 lines, full-width, so this HStack's
            // height (and therefore the thumbnail's centered position within it)
            // never changes when a card expands. The full summary text only
            // appears again, uncapped, inside `expandedDetails` below.
            HStack(alignment: .center, spacing: 12) {
                let glyph = FileTypeGlyph.symbol(for: node.filename)
                FileThumbnailView(path: node.path, glyphName: glyph.name, glyphTint: glyph.tint, maxWidth: 56, maxHeight: 56)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text(node.filename)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ArchivistPalette.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer().frame(width: 8)

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

                    // Tapping toggles the expanded metadata block below — kept
                    // deliberately capped at 2 lines here even when expanded (see
                    // the comment on the outer HStack above).
                    Text(node.summary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                        .lineLimit(2)
                        .contentShape(Rectangle())
                        .onTapGesture { isExpanded.toggle() }
                }
            }

            // Full card width, not indented past the thumbnail — a metadata
            // table describing the whole file, not a continuation of the text
            // column next to the thumbnail.
            if isExpanded {
                expandedDetails
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        // The hover tint sits in an overlay (drawn on top), not another
        // `.background` (which would land behind the white fill above and never
        // show) — this is what makes hovering ANYWHERE on the card react, not
        // just the text row, which used its own separate `.hoverHighlight` before.
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(isCardHovered ? 0.035 : 0))
        )
        .shadow(color: .black.opacity(0.11), radius: 16, x: 0, y: 4)
        .contentShape(Rectangle())
        .onHover { isCardHovered = $0 }
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
        }
    }

    /// Per skills/metadata-enrichment.md Step 5: the full summary plus
    /// Location/Created/Last updated — revealed together, below a divider,
    /// without disturbing the header row's fixed height above.
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Color(hex: "6E6E73").opacity(0.25))
                .frame(width: 324, height: 1)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Text(node.summary)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(ArchivistPalette.secondaryText)
                .padding(.bottom, 2)

            detailRow("Location", node.path, monospaced: true)
            detailRow("Created", Self.timestampFormatter.string(from: node.createdAt))
            detailRow("Last updated", Self.timestampFormatter.string(from: node.updatedAt))
        }
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "A6A6AB").opacity(0.8))
                .tracking(0.5)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(size: 11, design: .monospaced) : .system(size: 11))
                .foregroundStyle(Color(hex: "8A8A90").opacity(0.9))
                .lineLimit(monospaced ? 2 : 1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

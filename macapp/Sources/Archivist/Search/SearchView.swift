import SwiftUI
import AppKit

/// Graph-based search: query the GraphStore, show every sufficiently-relevant
/// match ranked best-first, each with what it's connected to (same_tag/
/// same_category/similar_content) — plan.md section 5/6.
struct SearchView: View {
    @ObservedObject var environment: AppEnvironment
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

            // Wrapped in its own `.frame(maxHeight: .infinity)` here, at the call
            // site — `EmptyStateView` already centers internally, but this VStack
            // only actually hands it the leftover space below the search field
            // when something at THIS level explicitly claims it; without this
            // wrapper the VStack was hugging its natural (compact) height and an
            // ancestor's `alignment: .top` was top-aligning that whole compact
            // block instead, leaving a dead gap below rather than truly centering.
            Group {
                if results.isEmpty {
                    // Only the "no matches" case gets text — that's feedback about
                    // what just happened, not generic how-to-use instruction. Before
                    // any search, the field's own placeholder already says how to use
                    // this screen, so nothing else here repeats it.
                    EmptyStateView(
                        systemImage: "doc.text.magnifyingglass",
                        instruction: hasSearched
                            // Explicit line break, not just a space — relying on
                            // natural word-wrap here split the sentence at an
                            // arbitrary word ("Try another word from the" / "file's
                            // name…") instead of at the sentence boundary.
                            ? "No matches for “\(query)”.\nTry another word from the file's name, content, or tag."
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 12)
        .onAppear(perform: applyPendingReviewedNodeIfNeeded)
        .onChange(of: environment.pendingReviewedNodeID) { _ in applyPendingReviewedNodeIfNeeded() }
    }

    /// Review's confirmation banner sets `environment.pendingReviewedNodeID` and
    /// switches to this tab so the just-resolved file's own card shows up
    /// immediately — a one-shot handoff, cleared right after being applied so it
    /// doesn't re-fire on every subsequent visit to this tab. Looks the node up
    /// directly by ID and shows exactly that one result, rather than routing it
    /// through the normal fuzzy `search(query:)` — searching by the raw filename
    /// (which was the earlier approach) let a generic token like "pdf" match
    /// every other PDF in the graph too.
    private func applyPendingReviewedNodeIfNeeded() {
        guard let nodeID = environment.pendingReviewedNodeID else { return }
        if let node = environment.store.node(id: nodeID) {
            query = node.filename
            results = [node]
            hasSearched = true
        }
        environment.pendingReviewedNodeID = nil
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
        results = environment.store.search(query: query, limit: Self.resultLimit)
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

    /// The header column's real, measured height WHILE COLLAPSED (filename row +
    /// up to 2 lines of summary) — captured once via the `GeometryReader`
    /// background below and only ever updated while `!isExpanded`. The thumbnail
    /// centers against this cached value instead of the column's live height, so
    /// expanding the summary (which grows the column) can never move it: the
    /// value it centers against simply stops changing the moment a card expands.
    @State private var collapsedContentHeight: CGFloat = 56

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                let glyph = FileTypeGlyph.symbol(for: node.filename)
                FileThumbnailView(path: node.path, glyphName: glyph.name, glyphTint: glyph.tint, maxWidth: 56, maxHeight: 56)
                    // Centers the thumbnail image within a box the height of the
                    // CACHED collapsed content, not the actual (possibly taller,
                    // expanded) row — this is what makes "centered" survive
                    // expansion instead of just approximating it via `.top`.
                    .frame(height: collapsedContentHeight, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text(node.filename)
                            .font(.system(size: 14, weight: .semibold))
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

                    // Tapping reveals the full summary in place (no separate,
                    // duplicated copy of it appears in `expandedDetails` below —
                    // that block is just the divider + metadata now).
                    Text(node.summary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                        .lineLimit(isExpanded ? nil : 2)
                        .contentShape(Rectangle())
                        .onTapGesture { isExpanded.toggle() }
                }
                // Measures this column's real height while collapsed and caches
                // it into `collapsedContentHeight` — guarded by `!isExpanded` so
                // the cache is frozen the instant a card expands, rather than
                // being overwritten by the taller expanded height.
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                if !isExpanded { collapsedContentHeight = geometry.size.height }
                            }
                            .onChange(of: geometry.size.height) { newHeight in
                                if !isExpanded { collapsedContentHeight = newHeight }
                            }
                    }
                )
            }

            // Full card width, not indented past the thumbnail — a metadata
            // table describing the whole file, not a continuation of the text
            // column next to the thumbnail. Spacing to it is entirely owned by
            // `expandedDetails`' own top padding (12px below the summary above),
            // not this VStack's spacing, which stays 0.
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
        // `allowsHitTesting(false)` is required here: an overlay is otherwise a
        // real hit-testable layer sitting above everything, including the summary
        // text's own tap-to-expand gesture below — without this, every tap on the
        // card (summary text included) was captured by this overlay and fell
        // through to the outer "reveal in Finder" gesture instead.
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(isCardHovered ? 0.035 : 0))
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.11), radius: 16, x: 0, y: 4)
        .contentShape(Rectangle())
        .onHover { isCardHovered = $0 }
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
        }
    }

    /// Per skills/metadata-enrichment.md Step 5: Location/Created/Last updated,
    /// below a divider — the full summary itself is already revealed in place
    /// above (see the header's own summary Text), not duplicated here.
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Bottom padding here is 4, not 10 — this VStack's own 6pt
            // `spacing` already adds 6pt between the divider and the first row
            // below it, so 4 + 6 = 10 total, matching spec. (Using the full 10
            // here would double-count that 6 and land at 16.)
            Rectangle()
                .fill(Color(hex: "6E6E73").opacity(0.25))
                .frame(width: 324, height: 1)
                .padding(.top, 12)
                .padding(.bottom, 4)

            detailRow("Location", node.path, monospaced: true)
            detailRow("Created", Self.timestampFormatter.string(from: node.createdAt))
            detailRow("Last updated", Self.timestampFormatter.string(from: node.updatedAt))
        }
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "A6A6AB").opacity(0.8))
                .tracking(0.5)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(size: 11, design: .monospaced) : .system(size: 11))
                .foregroundStyle(Color(hex: "8A8A90").opacity(0.9))
                // Single line, always — it's shown truncated with an ellipsis
                // either way (see `truncationMode` below), and a 2-line cap here
                // was reserving a second line's worth of height even though the
                // path only ever rendered on one, part of what was padding out
                // the space below the metadata block.
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

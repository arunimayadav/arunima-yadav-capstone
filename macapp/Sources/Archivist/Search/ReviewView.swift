import SwiftUI
import AppKit

/// Low-confidence files land here instead of being silently guessed at —
/// plan.md section 5 step 8 / section 8, skills/review.md.
///
/// On-demand only: this view (and ReviewActions underneath it) never runs on its
/// own, the user has to open the Review tab and act on each card themselves —
/// the watcher/Pipeline never calls into ReviewActions.
struct ReviewView: View {
    @ObservedObject var environment: AppEnvironment
    @State private var items: [Node] = []
    @State private var lastOutcome: String?
    /// The resulting (possibly renamed) filename to jump to in Search when the
    /// confirmation banner is tapped — nil for Reject, since a rejected file
    /// stays out of the review queue but isn't something this banner should
    /// invite you to go "view," and searching for it isn't the point of Reject.
    @State private var lastResolvedFilename: String?

    private var store: GraphStore { environment.store }
    private var settings: SettingsStore { environment.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lives at the view level, not per-card — a card unmounts the instant
            // its action resolves (it drops out of `items`), so any confirmation
            // state kept on the card itself would vanish before it could be seen.
            // This is the same gap Organize already had fixed for its own actions.
            if let lastOutcome {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(lastOutcome)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(ArchivistPalette.cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let lastResolvedFilename else { return }
                    environment.pendingSearchQuery = lastResolvedFilename
                    environment.selectedTab = .search
                }
            }

            Group {
                if items.isEmpty {
                    EmptyStateView(
                        systemImage: "checkmark.circle",
                        instruction: "Nothing needs your review right now."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(items) { node in
                                ReviewCard(node: node, store: store, settings: settings, onResolved: resolved)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 12)
        .onAppear(perform: refresh)
    }

    private func resolved(_ message: String, searchableFilename: String?) {
        lastOutcome = message
        lastResolvedFilename = searchableFilename
        refresh()
    }

    private func refresh() {
        items = store.pendingReview()
    }
}

/// One pending_review file: display fields (skills/review.md Step 2) plus
/// Accept/Edit/Reject (Step 3). Kept as its own view (rather than a stateless
/// row builder) because Edit needs per-card @State for the corrected fields.
private struct ReviewCard: View {
    let node: Node
    let store: GraphStore
    let settings: SettingsStore
    /// A human-readable summary of what just happened ("Accepted...", "Saved
    /// changes to...", "Rejected..."), plus the resulting filename to search for
    /// if the banner is tapped (nil for Reject — see `ReviewView`), for the
    /// parent's confirmation banner.
    let onResolved: (String, String?) -> Void

    @State private var isEditing = false
    @State private var isRevealHovered = false
    @State private var isReasoningExpanded = false
    @State private var category: FixedCategory
    @State private var docTypeText: String
    @State private var titleText: String

    init(node: Node, store: GraphStore, settings: SettingsStore, onResolved: @escaping (String, String?) -> Void) {
        self.node = node
        self.store = store
        self.settings = settings
        self.onResolved = onResolved
        // Normalized on entry — a stale pre-fixed-category record (like the
        // leftover "Course" values from before this system existed) shouldn't
        // make the picker show no selection at all.
        _category = State(initialValue: FixedCategory.from(node.category))
        _docTypeText = State(initialValue: node.docType)
        _titleText = State(initialValue: node.title)
    }

    var body: some View {
        // spacing: 0 throughout — every gap below is an explicit `.padding(.top,
        // …)` on the element that follows it instead, so nothing here can
        // silently double-count with a VStack `spacing` the way an earlier pass
        // on Search's cards did (a divider's own bottom padding plus the
        // VStack's spacing both adding up).
        VStack(alignment: .leading, spacing: 0) {
            header

            Rectangle()
                .fill(Color(hex: "6E6E73").opacity(0.25))
                .frame(height: 1)
                .padding(.top, 12)

            Text(node.summary)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(ArchivistPalette.secondaryText)
                .lineLimit(2)
                .padding(.top, 10)

            if !node.reasoning.isEmpty {
                // Collapsed to a single line by default — tapping expands it in
                // place, same "tap the secondary text to reveal the rest of it"
                // pattern Search's own summary uses.
                Text("Why it needs review: \(node.reasoning)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(ArchivistPalette.tertiaryText)
                    .lineLimit(isReasoningExpanded ? nil : 1)
                    .contentShape(Rectangle())
                    .onTapGesture { isReasoningExpanded.toggle() }
                    .padding(.top, 7)
            }

            if isEditing {
                editFields
                    .padding(.top, 8)
            }

            actions
                .padding(.top, 8)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.11), radius: 16, x: 0, y: 4)
    }

    /// No category/ownership/docType pills here anymore — the reviewer is about
    /// to choose the tag themselves (see the category picker below), so showing
    /// the model's own guess as a set of pills right above that choice was
    /// confusing rather than informative.
    ///
    /// Styled to match Search's result cards (thumbnail size, font sizes/colors,
    /// spacing) rather than its own separate look. `.center` alignment here is
    /// safe/stable (unlike Search's cards) since nothing in this specific HStack
    /// ever changes height — editing and reasoning-expansion both live in
    /// separate rows below it, not inside it — so the thumbnail genuinely stays
    /// centered against the filename + Reveal in Finder block always.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            let glyph = FileTypeGlyph.symbol(for: node.filename)
            FileThumbnailView(path: node.path, glyphName: glyph.name, glyphTint: glyph.tint, maxWidth: 56, maxHeight: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(node.filename)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ArchivistPalette.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                } label: {
                    Text("Reveal in Finder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor.opacity(isRevealHovered ? 0.75 : 1))
                        .underline(isRevealHovered)
                }
                .buttonStyle(.plain)
                .onHover { isRevealHovered = $0 }
            }

            Spacer(minLength: 4)
        }
    }

    private var editFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            categoryPicker
            labeledField("Doc type", text: $docTypeText)
            labeledField("Title", text: $titleText)
        }
    }

    /// One of exactly five fixed values (skills/tagging.md) — a picker, not a
    /// text field, since there's nothing else valid to type. Category IS the tag
    /// now, so choosing it here is the whole "assign a tag" decision; there's no
    /// separate tags field to also show.
    private var categoryPicker: some View {
        HStack(spacing: 6) {
            Text("Category")
                .font(ArchivistType.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Picker("", selection: $category) {
                ForEach(FixedCategory.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(ArchivistType.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(ArchivistType.body)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if isEditing {
                Button("Save & Accept") { saveEdit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Cancel") { isEditing = false }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button("Accept") { accept() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Edit") { isEditing = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Reject") { reject() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
            }
        }
    }

    // MARK: - Actions (skills/review.md Step 3/4, via ReviewActions)

    private func accept() {
        // Uses the RESULTING node's filename, not `node.filename` — File Action
        // (inside `resolve`) can rename the file as part of accepting it, so the
        // name the confirmation banner should search for is whatever it ended up
        // as on disk, not what it was called before acceptance.
        let result = ReviewActions.accept(node: node, store: store, settings: settings)
        onResolved("Accepted “\(node.filename)”.", result?.filename)
    }

    private func saveEdit() {
        let result = ReviewActions.edit(node: node, category: category.rawValue, docType: docTypeText, title: titleText,
                                         tags: [category.rawValue], store: store, settings: settings)
        onResolved("Saved changes to “\(node.filename)”.", result?.filename)
    }

    private func reject() {
        ReviewActions.reject(node: node, store: store)
        onResolved("Rejected “\(node.filename)”.", nil)
    }
}

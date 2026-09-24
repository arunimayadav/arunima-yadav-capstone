import SwiftUI
import AppKit

/// Low-confidence files land here instead of being silently guessed at —
/// plan.md section 5 step 8 / section 8, skills/review.md.
///
/// On-demand only: this view (and ReviewActions underneath it) never runs on its
/// own, the user has to open the Review tab and act on each card themselves —
/// the watcher/Pipeline never calls into ReviewActions.
struct ReviewView: View {
    let store: GraphStore
    let settings: SettingsStore
    @State private var items: [Node] = []
    @State private var lastOutcome: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lives at the view level, not per-card — a card unmounts the instant
            // its action resolves (it drops out of `items`), so any confirmation
            // state kept on the card itself would vanish before it could be seen.
            // This is the same gap Organize already had fixed for its own actions.
            if let lastOutcome {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(lastOutcome)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                }
                .padding(12)
                .background(ArchivistPalette.cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if items.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    instruction: "Nothing needs review — low-confidence files will show up here."
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
        .padding(.top, 12)
        .onAppear(perform: refresh)
    }

    private func resolved(_ message: String) {
        lastOutcome = message
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
    /// changes to...", "Rejected..."), for the parent's confirmation banner.
    let onResolved: (String) -> Void

    @State private var isEditing = false
    @State private var isRevealHovered = false
    @State private var category: FixedCategory
    @State private var docTypeText: String
    @State private var titleText: String

    init(node: Node, store: GraphStore, settings: SettingsStore, onResolved: @escaping (String) -> Void) {
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
        VStack(alignment: .leading, spacing: 6) {
            header

            Text(node.summary)
                .font(ArchivistType.body)
                .foregroundStyle(.secondary)
                .lineLimit(isEditing ? nil : 2)

            if !node.reasoning.isEmpty {
                Text("Why it needs review: \(node.reasoning)")
                    .font(ArchivistType.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
            }

            if isEditing {
                editFields
            }

            actions
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    /// No category/ownership/docType pills here anymore — the reviewer is about
    /// to choose the tag themselves (see the category picker below), so showing
    /// the model's own guess as a set of pills right above that choice was
    /// confusing rather than informative.
    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            let glyph = FileTypeGlyph.symbol(for: node.filename)
            FileThumbnailView(path: node.path, glyphName: glyph.name, glyphTint: glyph.tint, maxWidth: 36, maxHeight: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(node.filename)
                    .font(ArchivistType.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                } label: {
                    Text("Reveal in Finder")
                        .font(ArchivistType.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor.opacity(isRevealHovered ? 0.75 : 1))
                        .underline(isRevealHovered)
                }
                .buttonStyle(.plain)
                .onHover { isRevealHovered = $0 }
            }

            Spacer(minLength: 4)

            Text("\(Int(node.confidence * 100))%")
                .font(ArchivistType.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var editFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            categoryPicker
            labeledField("Doc type", text: $docTypeText)
            labeledField("Title", text: $titleText)
        }
        .padding(.top, 2)
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
        .padding(.top, 2)
    }

    // MARK: - Actions (skills/review.md Step 3/4, via ReviewActions)

    private func accept() {
        ReviewActions.accept(node: node, store: store, settings: settings)
        onResolved("Accepted “\(node.filename)”.")
    }

    private func saveEdit() {
        ReviewActions.edit(node: node, category: category.rawValue, docType: docTypeText, title: titleText,
                            tags: [category.rawValue], store: store, settings: settings)
        onResolved("Saved changes to “\(node.filename)”.")
    }

    private func reject() {
        ReviewActions.reject(node: node, store: store)
        onResolved("Rejected “\(node.filename)”.")
    }
}

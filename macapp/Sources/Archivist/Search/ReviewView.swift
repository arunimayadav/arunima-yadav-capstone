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
                            ReviewCard(node: node, store: store, settings: settings, onResolved: refresh)
                        }
                    }
                }
            }
        }
        .padding(14)
        .onAppear(perform: refresh)
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
    let onResolved: () -> Void

    @State private var isEditing = false
    @State private var categoryText: String
    @State private var docTypeText: String
    @State private var titleText: String
    @State private var tagsText: String

    init(node: Node, store: GraphStore, settings: SettingsStore, onResolved: @escaping () -> Void) {
        self.node = node
        self.store = store
        self.settings = settings
        self.onResolved = onResolved
        _categoryText = State(initialValue: node.category)
        _docTypeText = State(initialValue: node.docType)
        _titleText = State(initialValue: node.title)
        _tagsText = State(initialValue: node.tags.joined(separator: ", "))
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

    private var header: some View {
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
                    TagPill(text: node.ownership, tint: .purple)
                    if !node.docType.isEmpty {
                        TagPill(text: node.docType, tint: .gray)
                    }
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

            Spacer(minLength: 4)

            Text("\(Int(node.confidence * 100))%")
                .font(ArchivistType.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var editFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            labeledField("Category", text: $categoryText)
            labeledField("Doc type", text: $docTypeText)
            labeledField("Title", text: $titleText)
            labeledField("Tags", text: $tagsText)
        }
        .padding(.top, 2)
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
        onResolved()
    }

    private func saveEdit() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        ReviewActions.edit(node: node, category: categoryText, docType: docTypeText, title: titleText,
                            tags: tags, store: store, settings: settings)
        onResolved()
    }

    private func reject() {
        ReviewActions.reject(node: node, store: store)
        onResolved()
    }
}

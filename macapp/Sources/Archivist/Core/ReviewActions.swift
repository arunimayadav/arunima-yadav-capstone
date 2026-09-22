import Foundation

/// Implements skills/review.md Step 3 (Accept/Edit/Reject) and Step 4
/// (Relationship Builder re-run) — the only place a pending_review node's
/// resolution turns into an actual file move, graph write, and edge update.
///
/// This app has no separate "filed"/"flat" mode (that distinction was cut from
/// plan.md's revised scope) — Accept/Edit both land a resolved node at the same
/// `.indexed` status Pipeline already uses for a high-confidence auto-filed item,
/// per skill Step 3: "the exact same path as a high-confidence auto-filed item."
enum ReviewActions {
    /// Accept: "take the suggestion as-is." No fields change; it still goes
    /// through File Action and Relationship Builder just like Edit does.
    @discardableResult
    static func accept(node: Node, store: GraphStore, settings: SettingsStore) -> Node? {
        resolve(node: node, ownership: node.ownership, docType: node.docType, title: node.title,
                store: store, settings: settings)
    }

    /// Edit: "the corrected values overwrite the suggested ones on the node,
    /// then it proceeds through File Action exactly like Accept." A new tag
    /// introduced here goes through GraphStore's own reuse-over-sprawl tag
    /// upsert, same as the normal Tagging flow, not a separate ad hoc path.
    @discardableResult
    static func edit(node: Node, category: String, docType: String, title: String, tags: [String],
                      store: GraphStore, settings: SettingsStore) -> Node? {
        store.updateNode(id: node.id, category: category, summary: node.summary, tags: tags,
                          ownership: node.ownership, docType: docType, title: title)
        guard let updated = store.node(id: node.id) else { return nil }
        return resolve(node: updated, ownership: node.ownership, docType: docType, title: title,
                        store: store, settings: settings)
    }

    /// Reject: "leave the file untouched... mark it rejected rather than
    /// pending." No File Action, no Relationship Builder re-run — nothing about
    /// the node's content changed, only that it should stop resurfacing.
    static func reject(node: Node, store: GraphStore) {
        store.setStatus(id: node.id, status: .rejected)
        print("[Archivist][ReviewActions] \(node.filename): rejected — stays indexed/searchable, untouched on disk")
    }

    /// Shared tail for Accept/Edit: File Action (rename + Finder tags + move
    /// log), flip status to indexed, then re-run Relationship Builder so
    /// same_category/same_tag/similar_content edges reflect the corrected
    /// metadata rather than the original low-confidence guess (Step 4).
    private static func resolve(node: Node, ownership: String, docType: String, title: String,
                                 store: GraphStore, settings: SettingsStore) -> Node? {
        guard let filed = FileAction.apply(
            node: node, ownership: ownership, docType: docType, title: title,
            settings: settings, store: store, triggeredBy: "review"
        ) else {
            return nil
        }
        store.setStatus(id: filed.id, status: .indexed)
        guard let finalNode = store.node(id: filed.id) else { return nil }
        RelationshipBuilder.relate(node: finalNode, in: store)
        return finalNode
    }
}

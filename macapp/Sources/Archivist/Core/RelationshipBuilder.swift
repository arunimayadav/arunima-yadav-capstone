import Foundation

/// Turns shared tags/embedding similarity into graph edges — plan.md section 6.
/// Kept simple (compare against all existing nodes) since the graph is small by
/// design (plan.md section 8).
///
/// Deliberately does NOT create edges from shared category alone. It used to, but
/// category is a coarse administrative bucket (e.g. every "Course" file, regardless
/// of actual subject), not a genuine topical signal — in real use it connected
/// files with nothing in common besides both being schoolwork, which is exactly
/// the "Show related surfaces unrelated files" bug. Now that tagging enforces
/// "same category -> same tag" as a hard rule (see Pipeline's Step 0 check), a
/// same-category grouping that's actually meaningful already shows up as a
/// same_tag edge — same_category never adds information same_tag doesn't already
/// carry, just adds noise when category doesn't imply real similarity.
enum RelationshipBuilder {
    static func relate(node: Node, in store: GraphStore) {
        let others = store.allNodes().filter { $0.id != node.id }
        for other in others {
            let sharedTags = Set(node.tags).intersection(other.tags)
            if !sharedTags.isEmpty {
                store.upsertEdge(sourceId: node.id, targetId: other.id, type: .sameTag, weight: Double(sharedTags.count))
            }
            if !node.embedding.isEmpty && !other.embedding.isEmpty {
                let similarity = cosineSimilarity(node.embedding, other.embedding)
                if similarity > 0.75 {
                    store.upsertEdge(sourceId: node.id, targetId: other.id, type: .similarContent, weight: Double(similarity))
                }
            }
        }
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }
}

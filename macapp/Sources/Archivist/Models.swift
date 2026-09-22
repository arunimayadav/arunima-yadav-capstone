import Foundation

/// One indexed file. Mirrors the `nodes` table in plan.md section 7.
struct Node: Identifiable, Codable {
    var id: Int64
    var path: String
    var filename: String
    var category: String
    var summary: String
    var tags: [String]
    var confidence: Double
    var status: NodeStatus
    var providerUsed: String
    var extractedText: String
    var embedding: [Float]
    var contentHash: String
    var createdAt: Date
    var updatedAt: Date
    /// Carried over from the original understanding call specifically so
    /// skills/review.md can re-run Filename Nomenclature (Step 3, Accept/Edit)
    /// against a pending_review node without re-asking the AI for them.
    var ownership: String
    var docType: String
    var title: String
    var reasoning: String
}

enum NodeStatus: String, Codable {
    case indexed
    case pendingReview = "pending_review"
    case duplicateSkipped = "duplicate_skipped"
    /// skills/review.md Step 3: "leave the file untouched and mark it rejected
    /// rather than pending, so it stops resurfacing in the queue." Still
    /// indexed/searchable — only File Action and Relationship Builder skip it.
    case rejected
}

/// One entry in the append-only `moves` log.
struct MoveRecord: Identifiable, Codable {
    var id: Int64
    var nodeId: Int64
    var srcPath: String
    var dstPath: String
    var timestamp: Date
    var triggeredBy: String // "command" or "review"
    var reversed: Bool
}

/// One edge in the content graph.
struct Edge: Codable {
    var sourceNodeId: Int64
    var targetNodeId: Int64
    var edgeType: EdgeType
    var weight: Double
}

enum EdgeType: String, Codable {
    case sameTag = "same_tag"
    case sameCategory = "same_category"
    case similarContent = "similar_content"
}

/// The structured result of one AI understanding call, before it becomes a Node.
/// `ownership`, `docType`, and `title` exist specifically because they're the
/// `Input` fields skills/filename-nomenclature.md needs to build a filename — they
/// aren't otherwise used for search/tagging.
struct FileUnderstanding {
    var ownership: String // "own" or "other" — skills/filename-nomenclature.md Input
    var category: String
    var docType: String
    var title: String
    var summary: String
    var tags: [String]
    var confidence: Double
    var reasoning: String
}

/// Result of interpreting a free-text organization command, e.g.
/// "create a folder for anything related to my bank and put those files in it".
struct ParsedCommand {
    var destinationFolderName: String
    var searchQuery: String
}

import Foundation

/// The complete, closed set of categories — skills/tagging.md's fixed-vocabulary
/// system replacing the old open-ended AI-invented categories. The AI is
/// constrained to pick one of these five (see AIProvider's PromptBuilder); this
/// type is the code-level backstop in case a model drifts and returns something
/// else anyway.
///
/// Category doubles as the file's tag now — there's no separate open-ended
/// tagging decision anymore. That was a deliberate simplification: previous
/// real-world testing showed a local model given free rein to invent topical tags
/// produced inconsistent, sometimes actively wrong results (a Finance document
/// tagged "User Experience" because that tag happened to already exist from
/// unrelated files). A 5-way closed choice is a much easier, more reliable
/// classification task than open-ended tagging, and it's what makes rule #3
/// (one fixed color per category) possible at all — a hash-based color for an
/// unbounded tag vocabulary can't guarantee that the same 5-10 colors keep
/// meaning the same thing the way 5 fixed categories can.
enum FixedCategory: String, CaseIterable {
    case finance = "Finance"
    case academic = "Academic"
    case personal = "Personal"
    case health = "Health"
    case extra = "Extra"

    /// Case/whitespace-tolerant matching against the AI's raw output, falling back
    /// to `.extra` for anything that isn't one of the five allowed values — the
    /// prompt constrains the model to only return these, but a model can still
    /// drift, and "Extra" is explicitly the designated catch-all for exactly that.
    static func from(_ raw: String) -> FixedCategory {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return FixedCategory.allCases.first { $0.rawValue.lowercased() == normalized } ?? .extra
    }

    /// A fixed, permanent assignment — not computed/hashed, per the explicit
    /// requirement that every file in a category always gets the exact same
    /// Finder tag color. 1-7 indices are FinderLabelColor's classic Label order
    /// (Gray, Green, Purple, Blue, Yellow, Red, Orange); only 5 of the 7 are used.
    var finderLabelIndex: Int {
        switch self {
        case .finance: return 2  // Green
        case .academic: return 4 // Blue
        case .personal: return 3 // Purple
        case .health: return 6   // Red
        case .extra: return 1    // Gray
        }
    }
}

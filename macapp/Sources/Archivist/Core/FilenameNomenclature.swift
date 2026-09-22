import Foundation

/// Implements skills/filename-nomenclature.md's three-case naming pattern plus
/// its collision-resolution step directly. That skill is a deterministic
/// algorithm (case selection, pattern assembly, then collision resolution), not
/// a judgment call, so it's implemented here as code rather than a second AI
/// call — the AI-judgment inputs it needs (ownership/category/docType/title)
/// come from the same understanding call that also applies skills/tagging.md
/// (see AIProvider's PromptBuilder, which embeds both skill files' text verbatim).
enum FilenameNomenclature {
    struct Input {
        var ownership: String   // "own" or "other"
        var category: String
        var docType: String     // context only per the skill — not part of any pattern below
        var title: String
        var personName: String  // from Settings config — never inferred from the file
        var fileExtension: String
        /// The file's actual date (EXIF capture date, document date) if known —
        /// Case 1 only. nil means "unknown," which falls back to today's date.
        var fileDate: Date?
    }

    /// Extensions this skill treats as images — Step 1's `is_image` check.
    /// Determined here, from the extension, rather than threaded in as a
    /// separate flag, since it's a pure function of the file itself.
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "webp"
    ]

    /// Step 1 (pick the case) + Step 2 (assemble the name) + Step 3 (resolve
    /// collisions against what's already in the destination folder).
    static func filename(for input: Input, existingFilenames: Set<String>) -> String {
        let base = baseName(for: input)
        return resolveCollision(base: base, extension: input.fileExtension, existingFilenames: existingFilenames)
    }

    /// Step 1 + Step 2: "If is_image is true, apply Case 1... If is_image is
    /// false, apply Case 2 or Case 3 based on ownership." Case is decided purely
    /// by is_image and ownership — an image owned by the user still follows
    /// Case 1, never Case 3.
    private static func baseName(for input: Input) -> String {
        if imageExtensions.contains(input.fileExtension.lowercased()) {
            // CASE 1 — Images: <WhatItIs>_<dd-mm-yyyy>
            let whatItIs = collapseToHyphenToken(input.title)
            let date = input.fileDate ?? Date()
            return "\(whatItIs)_\(Self.imageDateFormatter.string(from: date))"
        }

        let category = collapseToToken(input.category)
        let title = collapseToToken(input.title)

        if input.ownership == "own" && !input.personName.isEmpty {
            // CASE 3 — owned by the user: <Category>_<Title>_<PersonFullName>
            return "\(category)_\(title)_\(collapseToToken(input.personName))"
        }

        // CASE 2 — not owned by the user: <Category>_<Title>
        return "\(category)_\(title)"
    }

    /// Step 3: "If the generated name already exists... append -2, -3, etc."
    private static func resolveCollision(base: String, extension ext: String, existingFilenames: Set<String>) -> String {
        var candidate = "\(base).\(ext)"
        guard existingFilenames.contains(candidate) else { return candidate }
        var counter = 2
        repeat {
            candidate = "\(base)-\(counter).\(ext)"
            counter += 1
        } while existingFilenames.contains(candidate)
        return candidate
    }

    /// "Remove characters that are invalid or awkward in filenames... leading/
    /// trailing whitespace" and match Cases 2/3's examples (PrototypingLecture,
    /// MidtermEssay, TUI320) by joining words with no separator, first letter
    /// of each word capitalized.
    private static func collapseToToken(_ raw: String) -> String {
        raw.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }

    /// Case 1's <WhatItIs> style is deliberately different from Cases 2/3: the
    /// skill's own examples (receipt, screenshot-login-error, whiteboard-notes)
    /// are lowercase and hyphen-separated, not TitleCase-joined.
    private static func collapseToHyphenToken(_ raw: String) -> String {
        raw.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { $0.lowercased() }
            .joined(separator: "-")
    }

    /// Case 1's date format, matching the skill's own example (19-09-2026).
    private static let imageDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()
}

import Foundation

/// Mirrors the graph's own tags onto the file as native macOS Finder tags, so the
/// organization is visible in Finder/Spotlight outside the app — plan.md section 6/8.
enum TagWriter {
    /// `category` is one of the five FixedCategory values — it IS the tag now,
    /// there's no separate open-ended tag anymore. Every file in a category gets
    /// that category's one permanent, fixed color (FixedCategory.finderLabelIndex),
    /// not a computed/hashed one — rule #3 of the fixed-category system: the same
    /// category always looks the same in Finder, by construction, not by luck.
    @discardableResult
    static func write(category: String, to url: URL) -> Bool {
        let fixedCategory = FixedCategory.from(category)
        let colorIndex = fixedCategory.finderLabelIndex // 1-7, fixed per category
        // Finder's sidebar entries under Tags ("Red", "Yellow", ...) are saved
        // searches matching files whose tag NAME is exactly one of these strings —
        // clicking "Yellow" does not look at the separate labelNumber attribute at
        // all, so one of these names has to actually be added as a real tag, not
        // just implied by a color-only attribute.
        let colorName = FinderLabelColor.names[colorIndex - 1]

        // The category name itself (e.g. "Finance") plus the color name (e.g.
        // "Green") — deduplicated in case they ever coincide.
        var seen = Set<String>()
        let finderTags = [fixedCategory.rawValue, colorName].filter { seen.insert($0).inserted }
        var success = true
        do {
            // Untyped NSURL API instead of URLResourceValues.tagNames — this SDK marks
            // the typed setter macOS 26+ only, but the underlying resource key works
            // fine on any macOS version that has Finder tags at all.
            try (url as NSURL).setResourceValue(finderTags, forKey: .tagNamesKey)
        } catch {
            print("[Archivist][TagWriter] FAILED to write Finder tags \(finderTags) to \(url.path): \(error)")
            success = false
        }

        // labelNumber is the classic, fully public/documented Finder color-label
        // resource key (distinct from tag names) — it's what actually produces the
        // colored dot in icon/list view. Set to the same index as colorName above,
        // so the dot's color and the sidebar tag name always agree.
        do {
            var mutableURL = url
            var values = URLResourceValues()
            values.labelNumber = colorIndex
            try mutableURL.setResourceValues(values)
        } catch {
            print("[Archivist][TagWriter] FAILED to set Finder label color for \(url.path): \(error)")
            success = false
        }

        return success
    }
}

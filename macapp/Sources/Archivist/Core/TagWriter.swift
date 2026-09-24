import Foundation

/// Mirrors the graph's own tags onto the file as native macOS Finder tags, so the
/// organization is visible in Finder/Spotlight outside the app — plan.md section 6/8.
enum TagWriter {
    @discardableResult
    static func write(category: String, tags: [String], to url: URL) -> Bool {
        // Keyed off the primary *tag* (what's actually shown in the UI's pill),
        // not category — category alone let files that share a category but ended
        // up with a stale/different tag (before Pipeline's Step-0 enforcement was
        // added) show mismatched colors. Now that "same category -> same tag" is
        // guaranteed upstream, keying on the tag directly means "same tag, same
        // color" holds unconditionally, not just as a side effect of category
        // hashing to the same bucket. FinderLabelColor is the single shared
        // computation the UI's pill also uses, so what's written here and what's
        // displayed there can never drift apart.
        let colorKey = tags.first ?? category
        let colorIndex = FinderLabelColor.index(for: colorKey) // 1-7
        // Finder's sidebar entries under Tags ("Red", "Yellow", ...) are saved
        // searches matching files whose tag NAME is exactly one of these strings —
        // clicking "Yellow" does not look at the separate labelNumber attribute at
        // all, so one of these names has to actually be added as a real tag, not
        // just implied by a color-only attribute.
        let colorName = FinderLabelColor.names[colorIndex - 1]

        // De-duplicated: the AI's own "tags" list can legitimately repeat the
        // category (e.g. category="Finance" and tags=["Finance", "Bank Statement"]),
        // and Finder shouldn't show the same tag label twice. The color name is
        // added as a genuine tag (see labelColorNames above) alongside the
        // descriptive ones, specifically so Finder's sidebar color filters work.
        var seen = Set<String>()
        let finderTags = ([category] + tags + [colorName]).filter { seen.insert($0).inserted }
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

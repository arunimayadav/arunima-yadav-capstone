import Foundation

/// macOS's 7 predefined Finder tag colors. Lives here (not in TagWriter or the UI
/// layer) so both sides share the same reference: TagWriter uses `names` to write
/// the real Finder tag, and the UI (see the Color extension in DesignSystem.swift)
/// uses `color(forIndex:)` to render a matching pill. Which index a given file
/// gets is decided by `FixedCategory.finderLabelIndex` — a fixed, permanent
/// per-category assignment, not computed from the file itself.
enum FinderLabelColor {
    /// Classic Finder Label order (long-standing AppleScript "label index" order).
    static let names = ["Gray", "Green", "Purple", "Blue", "Yellow", "Red", "Orange"]
}

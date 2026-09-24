import Foundation

/// macOS's 7 predefined Finder tag colors, and the deterministic mapping from a
/// tag/category string to one of them. Lives here (not in TagWriter or the UI
/// layer) specifically so both sides share the exact same computation: TagWriter
/// uses it to decide which color to actually write to the file, and the UI (see
/// SwiftUI's Color extension in DesignSystem.swift) uses it to render a pill that
/// matches — two independent implementations of "hash a string to a color" would
/// eventually drift and show a UI color that doesn't match what's really on disk.
enum FinderLabelColor {
    /// Classic Finder Label order (long-standing AppleScript "label index" order).
    static let names = ["Gray", "Green", "Purple", "Blue", "Yellow", "Red", "Orange"]

    /// 1-7, deterministic so the same string always maps to the same color.
    static func index(for value: String) -> Int {
        let hash = value.lowercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return (hash % 7) + 1
    }
}

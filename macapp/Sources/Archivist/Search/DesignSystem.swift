import SwiftUI
import AppKit

/// Shared visual language for the popover — small, reusable pieces so Search,
/// Review, and Organize read as one consistent system rather than three
/// independently-styled screens. Sizing follows macOS HIG type scale at the
/// popover's compact width: 13pt semibold for primary text (Headline), 11pt for
/// secondary/body text, 10pt for tertiary/metadata text (Caption).
enum ArchivistType {
    static let title = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 11, weight: .regular)
    static let caption = Font.system(size: 10, weight: .regular)
}

extension Color {
    /// "#RRGGBB" (with or without the leading `#`) — used for exact palette hex
    /// values that don't map to a system semantic color.
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        self.init(
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255
        )
    }
}

/// Exact palette values from the popover design spec — kept as named constants
/// rather than inlined hex strings so the same shade is guaranteed identical
/// everywhere it's used.
enum ArchivistPalette {
    static let segmentedBackground = Color(hex: "E8E8ED")
    static let searchFieldBackground = Color(hex: "EBEBEF")
    static let secondaryText = Color(hex: "6E6E73")
    static let placeholderText = Color(hex: "8E8E93")
    static let emptyStateIcon = Color(hex: "8E8E93").opacity(0.4)
    static let cardBackground = Color(hex: "F0F0F2")
    static let tertiaryText = Color(hex: "8E8E93")

    /// Dark-mode-aware: AppKit's own dynamic system colors, not fixed hex values —
    /// these are exactly what native macOS card/document surfaces use, so they
    /// already adapt correctly (near-white in light mode, appropriately dark in
    /// dark mode) without a hand-maintained light/dark pair.
    static let cardSurface = Color(nsColor: .controlBackgroundColor)
    static let pageSurface = Color(nsColor: .textBackgroundColor)

    /// Muted tint pairs for TagPill: a pale background with a saturated,
    /// same-hue foreground, rather than one color used at two opacities — matches
    /// the spec's explicit (background, text) pair for the default blue pill.
    static let tagBlueBackground = Color(hex: "E5F0FF")
    static let tagBlueForeground = Color(hex: "0066CC")
}

/// A small rounded label for a category/tag — the single source of "what kind of
/// file is this" on a card, replacing a separate keywords row. Uses an explicit
/// (background, foreground) pair rather than a single tint at varying opacity,
/// since the muted-pill look calls for two related-but-distinct shades, not just
/// one color diluted.
struct TagPill: View {
    let text: String
    var background: Color = ArchivistPalette.tagBlueBackground
    var foreground: Color = ArchivistPalette.tagBlueForeground

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .fixedSize() // hugs its text — never stretched or compressed by a parent HStack
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(foreground)
    }

    /// A pill colored to match the REAL macOS Finder tag color this exact category
    /// gets (or already has) written to disk — same fixed FixedCategory.
    /// finderLabelIndex mapping TagWriter uses, so the pill can never show a color
    /// that disagrees with what's actually on the file, and (per rule #3 of the
    /// fixed-category system) the same category always renders the same color.
    static func forFinderTag(_ tag: String) -> TagPill {
        let fixedCategory = FixedCategory.from(tag)
        let color = FinderLabelColor.color(forIndex: fixedCategory.finderLabelIndex)
        return TagPill(text: fixedCategory.rawValue, background: color.opacity(0.18), foreground: color)
    }
}

extension FinderLabelColor {
    /// Apple's standard system palette, in the same 1-7 order as `names` — the
    /// colors people already associate with these names elsewhere on macOS.
    static func color(forIndex index: Int) -> Color {
        switch index {
        case 1: return Color(hex: "8E8E93") // Gray
        case 2: return Color(hex: "34C759") // Green
        case 3: return Color(hex: "AF52DE") // Purple
        case 4: return Color(hex: "007AFF") // Blue
        case 5: return Color(hex: "FFCC00") // Yellow
        case 6: return Color(hex: "FF3B30") // Red
        default: return Color(hex: "FF9500") // Orange
        }
    }
}

/// Maps a file extension to an SF Symbol + tint, so results are scannable by type
/// at a glance the way Finder/Spotlight results are.
enum FileTypeGlyph {
    static func symbol(for filename: String) -> (name: String, tint: Color) {
        switch (filename as NSString).pathExtension.lowercased() {
        case "pdf": return ("doc.richtext.fill", .red)
        case "doc", "docx": return ("doc.text.fill", .blue)
        case "ppt", "pptx": return ("rectangle.on.rectangle.fill", .orange)
        case "txt", "md": return ("doc.plaintext.fill", .gray)
        default: return ("doc.fill", .gray)
        }
    }
}

/// A relative, human date string ("Today", "Yesterday", "3d ago", or a short date
/// for anything older) — compact enough for a card's top-right corner.
enum RelativeDate {
    static func string(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

/// Shared empty-state layout for Search, Organize, and Review: an icon plus one
/// instructional line, positioned slightly above true center rather than
/// perfectly centered. No example chips — removed by design decision in favor of
/// a plainer, quieter empty state.
struct EmptyStateView: View {
    let systemImage: String
    /// Optional — Search and Organize pass nil here since their field's own
    /// placeholder text is the only instructional copy those screens show;
    /// nothing else on screen duplicates it. Review still passes text since it
    /// has no input field to carry that role.
    var instruction: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ArchivistPalette.emptyStateIcon)
            if let instruction {
                Text(instruction)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ArchivistPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Applies a subtle hover highlight to any view — the standard feedback for
/// pointer-driven macOS UI (segmented tabs, the settings gear, cards, link-style
/// buttons) that SwiftUI doesn't provide automatically for custom-drawn controls.
struct HoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = 8
    var opacity: Double = 0.05
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? opacity : 0))
            )
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = 8, opacity: Double = 0.05) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius, opacity: opacity))
    }
}

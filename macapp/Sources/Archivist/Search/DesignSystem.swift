import SwiftUI

/// Shared visual language for the popover — small, reusable pieces so Search,
/// Review, and Organize read as one consistent system rather than three
/// independently-styled screens. Sizing follows macOS HIG type scale at the
/// popover's compact width: 13pt semibold for primary text (Headline), 11pt for
/// secondary/body text, 10pt for tertiary/metadata text (Caption).
enum ArchivistType {
    static let title = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 11, weight: .regular)
    static let caption = Font.system(size: 10, weight: .regular)
    static let pill = Font.system(size: 10, weight: .medium)
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
}

/// A small rounded label for a category/tag — the single source of "what kind of
/// file is this" on a card, replacing a separate keywords row.
struct TagPill: View {
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(ArchivistType.pill)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(tint.opacity(0.16), in: Capsule(style: .continuous))
            .foregroundStyle(tint)
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
    let instruction: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ArchivistPalette.emptyStateIcon)
            Text(instruction)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(ArchivistPalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
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

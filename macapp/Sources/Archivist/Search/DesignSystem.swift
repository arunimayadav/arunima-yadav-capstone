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
    static let chip = Font.system(size: 11, weight: .medium)
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

/// A tappable suggestion chip for empty states — filling in the text field with
/// an example, not executing anything itself.
struct ExampleChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(ArchivistType.chip)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Shared empty-state layout for Search and Organize: an icon, one instructional
/// line, and a wrapped row of example chips that seed the text field. Keeps both
/// tabs teaching the same way instead of just showing a blank list.
struct EmptyStateView: View {
    let systemImage: String
    let instruction: String
    let examples: [String]
    let onSelectExample: (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(instruction)
                .font(ArchivistType.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            // Wraps onto multiple lines rather than clipping/scrolling horizontally
            // — reads more like an iOS suggestions row.
            WrapLayout(spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    ExampleChip(text: example) { onSelectExample(example) }
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Minimal manual flow layout (no iOS-only `Layout` protocol dependency issues) —
/// arranges children left-to-right, wrapping to a new row when the next child
/// would overflow the available width.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

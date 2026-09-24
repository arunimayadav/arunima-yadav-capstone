import SwiftUI

enum ArchivistTab: CaseIterable, Identifiable {
    case search
    case command
    case review
    case settings
    var id: Self { self }
}

/// The single dropdown surface for the whole app — plan.md section 6's
/// "Search · Settings · Review · Commands" menu bar app shell.
///
/// The whole view is pinned to one fixed size (`Self.size`, matching
/// `StatusPanel`'s size). Without this, switching to a tab with different
/// intrinsic content (e.g. Settings' `Form` wants to grow taller than Search's
/// `List`) resizes the panel *after* it's already anchored to the status item,
/// which could drift the window upward past the top of the screen instead of
/// just growing downward. Fixing the size up front avoids that class of bug entirely.
///
/// Background and corner rounding are NOT set here — `StatusPanel` wraps this
/// view in a real `NSVisualEffectView` (`.underWindowBackground` material) and
/// clips it to `Self.cornerRadius` at the AppKit layer, which is what actually
/// produces a native Control-Center-style blur-through of whatever is behind the
/// dropdown. A SwiftUI `.background(.ultraThinMaterial)` here would only ever
/// tint on top of that, so this view stays transparent and lets the panel's own
/// material show through everywhere it isn't covered by a card.
///
/// The single `.padding(16)` below is the whole content's margin from the panel
/// edge on all four sides (per spec) — individual tabs (Search/Organize/Review)
/// must NOT also pad their own edges, only their internal spacing between rows,
/// or the margin would double up.
struct ContentView: View {
    @ObservedObject var environment: AppEnvironment

    static let size = NSSize(width: 380, height: 320)
    static let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            TopBar(selectedTab: $environment.selectedTab)

            Group {
                switch environment.selectedTab {
                case .search:
                    SearchView(store: environment.store)
                case .command:
                    CommandView(interpreter: environment.commandInterpreter)
                case .review:
                    ReviewView(store: environment.store, settings: environment.settings)
                case .settings:
                    SettingsView(settings: environment.settings)
                }
            }
            // Explicit .top alignment is the actual fix here, not decoration: without
            // it this frame defaults to centering its content, so any tab whose
            // content is shorter than the full popover height (e.g. Organize with
            // just its input field showing, once the empty state that used to fill
            // the space disappears) visibly jumps from the top to the middle the
            // instant that filler content goes away.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(16)
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

/// The tab row: a custom segmented control (native `Picker(.segmented)` can't be
/// restyled to exact spec colors/shadow) plus a separate circular settings button,
/// per spec: distinct elements sharing one row, not one control with 4 segments.
private struct TopBar: View {
    @Binding var selectedTab: ArchivistTab
    @State private var hoveredTab: ArchivistTab?
    @State private var isGearHovered = false

    private let tabs: [(tab: ArchivistTab, label: String)] = [
        (.search, "Search"), (.command, "Organize"), (.review, "Review")
    ]

    var body: some View {
        HStack(spacing: 16) {
            segmentedControl
            gearButton
        }
    }

    /// Base fill + a row of hairline dividers UNDER the segments layer, so a
    /// selected (or hovered) segment's own pill naturally paints over the divider
    /// at its edges instead of a line visibly slicing through it — matching how
    /// native macOS segmented controls hide dividers behind the active segment.
    private var segmentedControl: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ArchivistPalette.segmentedBackground)
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.segmentWidth, height: Self.controlHeight)
                divider
                Color.clear.frame(width: Self.segmentWidth, height: Self.controlHeight)
                divider
                Color.clear.frame(width: Self.segmentWidth, height: Self.controlHeight)
            }
            HStack(spacing: 0) {
                ForEach(tabs, id: \.tab) { entry in
                    segment(entry.tab, entry.label)
                }
            }
        }
        .frame(width: Self.controlWidth, height: Self.controlHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private static let controlWidth: CGFloat = 300
    private static let controlHeight: CGFloat = 30
    private static let segmentWidth: CGFloat = 100

    private var divider: some View {
        Rectangle()
            .fill(ArchivistPalette.secondaryText.opacity(0.25))
            .frame(width: 0.5, height: 24)
    }

    private func segment(_ tab: ArchivistTab, _ label: String) -> some View {
        let isSelected = selectedTab == tab
        return Text(label)
            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? ArchivistPalette.primaryText : ArchivistPalette.secondaryText)
            .frame(width: Self.segmentWidth, height: Self.controlHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .frame(height: 26)
                        .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 1)
                } else if hoveredTab == tab {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                        .frame(height: 26)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedTab = tab }
            .onHover { hovering in hoveredTab = hovering ? tab : nil }
    }

    private var gearButton: some View {
        Button {
            selectedTab = .settings
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .regular))
        }
        .buttonStyle(StatefulIconButtonStyle(
            isHovered: isGearHovered,
            hitSize: 32,
            normalColor: Color(hex: "5F6065"),
            hoverColor: Color(hex: "2C2C2E"),
            pressedColor: ArchivistPalette.primaryText,
            hoverBackground: Color.black.opacity(0.075),
            pressedBackground: Color.black.opacity(0.135),
            pressedScale: 0.97
        ))
        .onHover { isGearHovered = $0 }
    }
}

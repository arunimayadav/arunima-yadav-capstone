import SwiftUI

enum ArchivistTab: CaseIterable, Identifiable {
    case search
    case command
    case review
    case settings
    var id: Self { self }
}

/// The single popover surface for the whole app — plan.md section 6's
/// "Search · Settings · Review · Commands" menu bar app shell.
///
/// The whole view is pinned to one fixed size (`Self.size`, matching
/// `AppDelegate.popoverSize`). Without this, switching to a tab with different
/// intrinsic content (e.g. Settings' `Form` wants to grow taller than Search's
/// `List`) resizes the popover *after* it's already anchored to the status item,
/// and NSPopover can drift the window upward past the top of the screen instead of
/// just growing downward. Fixing the size up front avoids that class of bug entirely.
///
/// Styled to read as native system chrome rather than a plain white panel: a
/// translucent material background (like Control Center / Notification Center)
/// behind continuous ("squircle") rounded corners, at a more compact size than a
/// typical document window.
struct ContentView: View {
    @ObservedObject var environment: AppEnvironment

    static let size = NSSize(width: 380, height: 520)
    private static let cornerRadius: CGFloat = 16

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
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.ultraThinMaterial)
        // SwiftUI's `.continuous` style is the same squircle-interpolation corner
        // Apple's own system chrome uses (app icons, Control Center) — the closest
        // native equivalent to a Figma "corner smoothing" value; SwiftUI doesn't
        // expose a separate numeric smoothing parameter to tune further.
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { entry in
                segment(entry.tab, entry.label)
            }
        }
        .padding(2)
        .frame(height: 32)
        .background(ArchivistPalette.segmentedBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func segment(_ tab: ArchivistTab, _ label: String) -> some View {
        let isSelected = selectedTab == tab
        return Text(label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? Color.black : ArchivistPalette.secondaryText)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                } else if hoveredTab == tab {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedTab = tab }
            .onHover { hovering in hoveredTab = hovering ? tab : nil }
    }

    private var gearButton: some View {
        let isSelected = selectedTab == .settings
        return Button {
            selectedTab = .settings
        } label: {
            ZStack {
                Circle().fill(ArchivistPalette.segmentedBackground)
                if isSelected {
                    Circle().fill(Color.black.opacity(0.08))
                } else if isGearHovered {
                    Circle().fill(Color.black.opacity(0.05))
                }
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(ArchivistPalette.secondaryText)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .onHover { isGearHovered = $0 }
    }
}

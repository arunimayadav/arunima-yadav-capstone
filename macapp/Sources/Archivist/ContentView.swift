import SwiftUI

enum ArchivistTab: String, CaseIterable, Identifiable {
    case search = "Search"
    case command = "Organize"
    case review = "Review"
    case settings = "Settings"
    var id: String { rawValue }
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
    @State private var tab: ArchivistTab = .search

    static let size = NSSize(width: 380, height: 460)
    private static let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(ArchivistTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider().opacity(0.5)

            Group {
                switch tab {
                case .search:
                    SearchView(store: environment.store)
                case .command:
                    CommandView(interpreter: environment.commandInterpreter)
                case .review:
                    ReviewView(store: environment.store)
                case .settings:
                    SettingsView(settings: environment.settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

import AppKit
import SwiftUI
import Combine

/// Menu bar shell: NSStatusItem in the top toolbar, no Dock icon (.accessory),
/// clicking opens a popover hosting ContentView — plan.md section 2/6.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let environment = AppEnvironment()
    private var reviewCountCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Archivist][AppDelegate] applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)

        let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem.button {
            button.image = Self.icon(withBadge: false)
            button.action = #selector(togglePopover)
            button.target = self
            print("[Archivist][AppDelegate] menu bar status item created")
        } else {
            print("[Archivist][AppDelegate] WARNING: statusBarItem.button was nil — no menu bar icon will show")
        }
        self.statusItem = statusBarItem

        // Same idea as an app icon's unread-count badge: a small red dot appears
        // on the menu bar icon whenever a file is waiting in Review, and clears
        // itself the moment the count drops back to zero.
        reviewCountCancellable = environment.$pendingReviewCount
            .map { $0 > 0 }
            .removeDuplicates()
            .sink { [weak self] hasBadge in
                self?.statusItem?.button?.image = Self.icon(withBadge: hasBadge)
            }

        let contentView = ContentView(environment: environment)
        let hostingController = NSHostingController(rootView: contentView)
        // Fixed size set explicitly (matching ContentView.size) before the popover
        // is ever shown — see the comment on ContentView for why leaving this to
        // SwiftUI's automatic sizing let the window drift off the top of the screen.
        hostingController.preferredContentSize = ContentView.size
        let popover = NSPopover()
        popover.contentViewController = hostingController
        popover.contentSize = ContentView.size
        popover.behavior = .transient
        self.popover = popover

        environment.startWatching()
        print("[Archivist][AppDelegate] launch sequence complete")
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.stopWatching()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Clicking with a badge showing jumps straight to Review — that's the
            // whole point of the badge, the same way clicking a Mail unread count
            // takes you to the inbox rather than wherever you last were.
            environment.refreshReviewCount()
            environment.selectedTab = environment.pendingReviewCount > 0 ? .review : .search
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Composites a small red dot onto the folder glyph's top-right corner. The
    /// base glyph is drawn tinted with `labelColor` (a dynamic system color) rather
    /// than left as a template image, because a template image would have its red
    /// dot flattened to the same monochrome tint as everything else — compositing
    /// forces us to handle light/dark adaptation ourselves instead of getting it
    /// for free from `NSStatusBarButton`'s automatic template rendering.
    private static func icon(withBadge: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        guard let symbol = NSImage(systemSymbolName: "folder", accessibilityDescription: "Archivist") else {
            return NSImage(size: size)
        }

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.labelColor.set()
        symbol.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)

        if withBadge {
            // 8x8 red dot with a 1px white border separating it from the glyph —
            // inset from the true corner by the border width so the border itself
            // doesn't get clipped by the canvas edge.
            let diameter: CGFloat = 8
            let borderWidth: CGFloat = 1
            let dotRect = NSRect(x: size.width - diameter - borderWidth, y: size.height - diameter - borderWidth,
                                  width: diameter, height: diameter)
            let borderRect = dotRect.insetBy(dx: -borderWidth, dy: -borderWidth)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: borderRect).fill()
            NSColor(red: 1.0, green: 0x3B / 255.0, blue: 0x30 / 255.0, alpha: 1).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }
        image.unlockFocus()
        return image
    }
}

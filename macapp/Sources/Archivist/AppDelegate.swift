import AppKit
import SwiftUI
import Combine

/// Menu bar shell: NSStatusItem in the top toolbar, no Dock icon (.accessory),
/// clicking opens a floating panel hosting ContentView — plan.md section 2/6.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var panel: StatusPanel?
    private let environment = AppEnvironment()
    private var reviewCountCancellable: AnyCancellable?
    private var clickOutsideMonitor: Any?

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

        let panel = StatusPanel(size: ContentView.size, cornerRadius: ContentView.cornerRadius) {
            ContentView(environment: self.environment)
        }
        panel.delegate = self
        self.panel = panel

        environment.startWatching()
        print("[Archivist][AppDelegate] launch sequence complete")
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.stopWatching()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let panel else { return }
        if panel.isVisible {
            closePanel()
        } else {
            // Clicking with a badge showing jumps straight to Review — that's the
            // whole point of the badge, the same way clicking a Mail unread count
            // takes you to the inbox rather than wherever you last were.
            environment.refreshReviewCount()
            environment.selectedTab = environment.pendingReviewCount > 0 ? .review : .search
            showPanel(relativeTo: button)
        }
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
        guard let panel, let buttonWindow = button.window else { return }
        let buttonFrameOnScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelSize = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: buttonFrameOnScreen.midX - panelSize.width / 2,
            y: buttonFrameOnScreen.minY - panelSize.height - 4
        ))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Stands in for NSPopover's old `.behavior = .transient` — a global
        // monitor only fires for events outside our own app, which is exactly
        // "clicked away from the dropdown" for a panel that has no other windows.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
            self.clickOutsideMonitor = nil
        }
    }

    /// Cmd+Tab away, Mission Control, a screen lock, etc. — anything that takes
    /// key focus without a click the global mouse monitor above would catch.
    func windowDidResignKey(_ notification: Notification) {
        closePanel()
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

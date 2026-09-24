import AppKit
import SwiftUI

/// A borderless, floating panel styled like native macOS menu bar dropdowns
/// (Control Center, Wi-Fi, Bluetooth) — real background blur via
/// `NSVisualEffectView` and a large continuous corner radius, neither of which
/// `NSPopover` can actually give: NSPopover always draws its own opaque bezel
/// underneath whatever SwiftUI background material the content view sets, so no
/// amount of `.ultraThinMaterial` there ever shows a real blur-through of
/// whatever is behind the panel, and its corner radius isn't ours to change.
/// This panel replaces that chrome entirely with the same `NSVisualEffectView`
/// material (`.popover`) the system itself uses for this kind of surface.
final class StatusPanel: NSPanel {
    init<Content: View>(size: NSSize, cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        // The window's own shadow is turned off in favor of a hand-tuned one
        // (below) matching an exact spec (0/6/24, ~16% black) — the system
        // default shadow doesn't expose blur radius or opacity as public API.
        hasShadow = false
        level = .popUpMenu
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Unmasked container: holds the shadow, which needs to paint OUTSIDE the
        // rounded content's bounds. Putting the shadow directly on `effectView`
        // wouldn't work — that layer has `masksToBounds = true` for the corner
        // radius, and masking clips the shadow along with everything else.
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.masksToBounds = false
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.16
        container.layer?.shadowRadius = 24
        container.layer?.shadowOffset = CGSize(width: 0, height: -6) // AppKit layers are y-up; negative moves the shadow down

        let effectView = NSVisualEffectView()
        // `.underWindowBackground` was tried here first but is documented for
        // blurring content *within* the same window (e.g. behind a toolbar) —
        // used with `.behindWindow` blending on a standalone floating panel it
        // rendered as a flat, fully opaque fill, which is worse than the
        // starting point. `.menu` is what NSMenu itself uses for exactly this
        // "floats over the desktop with real blur-through" case, and is the
        // closest public material to genuine Control-Center-style glass.
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        // `.active` rather than `.followsWindowActiveState` — a status-bar
        // dropdown isn't a real window the user thinks of as "active/inactive",
        // it should always render at full vibrancy the instant it's shown, not
        // dim because the nonactivating panel didn't take key focus yet.
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true
        // The thin bright rim around the edge that reads as "glass" even where
        // there's nothing colorful behind the panel for the blur itself to show —
        // a low-opacity white border, not a real reflection, but the same visual
        // shorthand real glass/HUD surfaces use.
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.11).cgColor

        let hosting = NSHostingView(rootView: content())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effectView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        effectView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: container.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.contentView = container
    }

    /// A `.nonactivatingPanel` can't become key by default, which would silently
    /// break typing in Search/Organize's text fields — this is what makes the
    /// panel a real interactive surface instead of a floating decoration.
    override var canBecomeKey: Bool { true }
}

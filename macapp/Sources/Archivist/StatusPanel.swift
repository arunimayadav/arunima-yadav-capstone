import AppKit
import SwiftUI

/// A borderless, floating panel styled like native macOS menu bar dropdowns
/// (Control Center, Wi-Fi, Bluetooth) — real background blur via a genuine
/// Liquid Glass surface, and a large continuous corner radius, neither of which
/// `NSPopover` can actually give: NSPopover always draws its own opaque bezel
/// underneath whatever SwiftUI background material the content view sets, so no
/// amount of `.ultraThinMaterial` there ever shows a real blur-through of
/// whatever is behind the panel, and its corner radius isn't ours to change.
/// This panel replaces that chrome entirely.
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
        // rounded content's bounds. Putting the shadow directly on the glass/
        // effect view wouldn't work — that layer clips to its own corner radius,
        // and clipping takes the shadow down with everything else.
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.masksToBounds = false
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.16
        container.layer?.shadowRadius = 24
        container.layer?.shadowOffset = CGSize(width: 0, height: -6) // AppKit layers are y-up; negative moves the shadow down

        let hosting = NSHostingView(rootView: content())
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let glassContainer: NSView
        if #available(macOS 26.0, *) {
            // The real Liquid Glass surface (introduced macOS 26) — not an
            // approximation via NSVisualEffectView material tuning, which
            // topped out looking like a flat, only mildly translucent card no
            // matter which material was tried (.popover/.menu/etc.) versus the
            // genuinely see-through, refractive look system panels (Wi-Fi,
            // Control Center) actually have on this OS. `contentView` is a
            // dedicated property this view manages the sizing of internally,
            // unlike NSVisualEffectView which needs its subview constrained
            // manually (see the fallback branch below).
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.style = .regular
            glass.contentView = hosting
            glassContainer = glass
        } else {
            // Fallback for macOS < 26 (this project's declared minimum is 13) —
            // `.menu` is what NSMenu itself uses for floating over the desktop
            // with real blur-through, the closest pre-Liquid-Glass public
            // material to this same effect.
            let effectView = NSVisualEffectView()
            effectView.material = .menu
            effectView.blendingMode = .behindWindow
            // `.active` rather than `.followsWindowActiveState` — a status-bar
            // dropdown should always render at full vibrancy the instant it's
            // shown, not dim because the nonactivating panel didn't take key
            // focus yet.
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = cornerRadius
            effectView.layer?.cornerCurve = .continuous
            effectView.layer?.masksToBounds = true
            // A thin bright rim around the edge that reads as "glass" even
            // where there's nothing colorful behind the panel for the blur
            // itself to show — real Liquid Glass provides this natively, so
            // it's only needed on this older-OS fallback path.
            effectView.layer?.borderWidth = 1
            effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.11).cgColor

            effectView.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: effectView.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
            ])
            glassContainer = effectView
        }

        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(glassContainer)
        NSLayoutConstraint.activate([
            glassContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            glassContainer.topAnchor.constraint(equalTo: container.topAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.contentView = container
    }

    /// A `.nonactivatingPanel` can't become key by default, which would silently
    /// break typing in Search/Organize's text fields — this is what makes the
    /// panel a real interactive surface instead of a floating decoration.
    override var canBecomeKey: Bool { true }
}

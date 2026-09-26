import AppKit

/// A borderless, pitch-black window that covers exactly one NSScreen.
/// Sits above the shield level so it covers the menu bar, the Dock, full
/// screen apps, and follows the user across every Space.
final class OverlayWindow: NSWindow {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // The level macOS itself uses to shield the screen (e.g. during
        // fast user switching / screen lock) — above the menu bar, Dock,
        // the screen saver, and full-screen apps.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

        let blackView = NSView(frame: screen.frame)
        blackView.wantsLayer = true
        blackView.layer?.backgroundColor = NSColor.black.cgColor
        contentView = blackView

        setFrame(screen.frame, display: true)
    }

    func show() {
        orderFrontRegardless()
    }
}

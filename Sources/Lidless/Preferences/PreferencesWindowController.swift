import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {

    init(preferences: PreferencesStore, hotkeyManager: GlobalHotkeyManager?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Lidless Preferences"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.contentView = NSHostingView(
            rootView: PreferencesView(preferences: preferences, hotkeyManager: hotkeyManager)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

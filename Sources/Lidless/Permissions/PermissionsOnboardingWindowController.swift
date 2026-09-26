import AppKit
import SwiftUI

final class PermissionsOnboardingWindowController: NSWindowController {

    private let onRecheck: () -> Void

    init(onRecheck: @escaping () -> Void) {
        self.onRecheck = onRecheck

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Lidless"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.contentView = NSHostingView(
            rootView: PermissionsOnboardingView(
                onOpenSettings: { PermissionsManager.shared.openAccessibilitySettings() },
                onRequestPrompt: { PermissionsManager.shared.requestAccessibilityPrompt() },
                onRecheck: { [weak self] in
                    onRecheck()
                    self?.close()
                },
                onDismiss: { [weak self] in self?.close() }
            )
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

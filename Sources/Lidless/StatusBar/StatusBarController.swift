import AppKit
import Combine

/// Owns the NSStatusItem and its menu, and reflects BlackoutController's
/// state (icon + checkmark) without the rest of the app needing to know
/// AppKit menu details exist.
final class StatusBarController {

    private let statusItem: NSStatusItem
    private let toggleMenuItem: NSMenuItem
    private let permissionsMenuItem: NSMenuItem
    private let blackoutController: BlackoutController
    private var cancellables = Set<AnyCancellable>()

    private let onOpenPreferences: () -> Void
    private let onCheckPermissions: () -> Void
    private let onQuit: () -> Void

    init(
        blackoutController: BlackoutController,
        onOpenPreferences: @escaping () -> Void,
        onCheckPermissions: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.blackoutController = blackoutController
        self.onOpenPreferences = onOpenPreferences
        self.onCheckPermissions = onCheckPermissions
        self.onQuit = onQuit

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleMenuItem = NSMenuItem(title: "Start Blackout", action: nil, keyEquivalent: "")
        permissionsMenuItem = NSMenuItem(title: "Check Permissions", action: nil, keyEquivalent: "")

        configureButton()
        configureMenu()
        observeBlackoutState()
    }

    private func configureButton() {
        if let button = statusItem.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
            button.image?.accessibilityDescription = "Lidless"
        }
    }

    private func configureMenu() {
        let menu = NSMenu()

        toggleMenuItem.target = self
        toggleMenuItem.action = #selector(toggleBlackout)
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        permissionsMenuItem.target = self
        permissionsMenuItem.action = #selector(checkPermissions)
        menu.addItem(permissionsMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Lidless", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func observeBlackoutState() {
        blackoutController.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.updateForBlackoutState(isActive)
            }
            .store(in: &cancellables)
    }

    private func updateForBlackoutState(_ isActive: Bool) {
        toggleMenuItem.title = isActive ? "Stop Blackout" : "Start Blackout"
        toggleMenuItem.state = isActive ? .on : .off
    }

    func updatePermissionState(trusted: Bool) {
        permissionsMenuItem.title = trusted ? "Permissions Granted ✓" : "Check Permissions ⚠️"
    }

    @objc private func toggleBlackout() {
        blackoutController.toggle()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
    }

    @objc private func checkPermissions() {
        onCheckPermissions()
    }

    @objc private func quit() {
        onQuit()
    }
}

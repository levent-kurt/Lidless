import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var blackoutController: BlackoutController?
    private var hotkeyManager: GlobalHotkeyManager?
    private var preferencesWindowController: PreferencesWindowController?
    private var permissionsOnboardingWindowController: PermissionsOnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let preferences = PreferencesStore.shared
        let blackoutController = BlackoutController(preferences: preferences)
        self.blackoutController = blackoutController

        statusBarController = StatusBarController(
            blackoutController: blackoutController,
            onOpenPreferences: { [weak self] in self?.showPreferences() },
            onCheckPermissions: { [weak self] in self?.checkPermissions(showOnboardingIfNeeded: true) },
            onQuit: { NSApp.terminate(nil) }
        )

        hotkeyManager = GlobalHotkeyManager(preferences: preferences) { [weak blackoutController] in
            blackoutController?.toggle()
        }
        hotkeyManager?.registerCurrentShortcut()

        checkPermissions(showOnboardingIfNeeded: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        blackoutController?.forceStopImmediately()
        hotkeyManager?.unregister()
    }

    private func checkPermissions(showOnboardingIfNeeded: Bool) {
        let trusted = PermissionsManager.shared.isAccessibilityTrusted()
        statusBarController?.updatePermissionState(trusted: trusted)

        if !trusted && showOnboardingIfNeeded {
            showPermissionsOnboarding()
        }
    }

    private func showPermissionsOnboarding() {
        if permissionsOnboardingWindowController == nil {
            permissionsOnboardingWindowController = PermissionsOnboardingWindowController(
                onRecheck: { [weak self] in self?.checkPermissions(showOnboardingIfNeeded: false) }
            )
        }
        permissionsOnboardingWindowController?.show()
    }

    private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                preferences: PreferencesStore.shared,
                hotkeyManager: hotkeyManager
            )
        }
        preferencesWindowController?.show()
    }
}

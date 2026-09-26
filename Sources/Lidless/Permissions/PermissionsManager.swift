import AppKit
import ApplicationServices

/// Accessibility permission is what lets Lidless's CGEventTap observe
/// keyboard/mouse activity system-wide so it knows when to end Blackout
/// Mode. Without it, the wake-up detector simply never fires.
final class PermissionsManager {

    static let shared = PermissionsManager()

    private init() {}

    func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system's own "Lidless would like to control this
    /// computer" prompt, which adds the app to the Accessibility list
    /// (unchecked) if it isn't there yet.
    @discardableResult
    func requestAccessibilityPrompt() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

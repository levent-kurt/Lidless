import Foundation

/// Swift-facing wrapper around the private-API bridge in
/// KeyboardBacklightBridge.m. Saves the backlight level before turning it
/// off so Blackout Mode can restore exactly what the user had.
final class KeyboardBacklightController {

    private var savedLevel: Float?

    /// Turns the keyboard backlight fully off, remembering the previous
    /// level so `restore()` can put it back.
    func turnOffAndRemember() {
        let current = LidlessGetKeyboardBrightness()
        savedLevel = current >= 0 ? current : nil
        _ = LidlessSetKeyboardBrightness(0.0)
    }

    /// Restores the previously saved backlight level. If nothing was ever
    /// saved (private API unavailable), this is a no-op.
    func restore() {
        guard let savedLevel else { return }
        _ = LidlessSetKeyboardBrightness(savedLevel)
        self.savedLevel = nil
    }
}

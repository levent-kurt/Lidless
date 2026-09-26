import AppKit

/// Controls the built-in keyboard backlight by simulating presses of the
/// keyboard's own brightness media key (the same NX_KEYTYPE_ILLUMINATION_*
/// system-defined event a physical Fn key generates). There is no working
/// programmatic brightness API on Apple Silicon — CoreBrightness's private
/// KeyboardBrightnessClient class was tried and confirmed to accept a
/// setter call and report success while having zero effect on the actual
/// hardware. Simulating the media key is the one mechanism confirmed, on
/// real hardware, to actually move the backlight.
///
/// This does trigger the system's on-screen brightness HUD, same as
/// pressing the real key would. BlackoutController is responsible for
/// calling `turnOffAndRemember()` only after its overlay windows are
/// already up (and `restore()` only before they come down), since the
/// overlay sits at a higher window level than that HUD and hides it.
final class KeyboardBacklightController {

    /// Best-effort guess at the keyboard's brightness step count, used to
    /// scale how many "up" presses approximate the previous level on
    /// restore. Apple hasn't published this; 16 matches the commonly
    /// observed step count on current keyboards. A few extra presses in
    /// either direction only run past the end of the range harmlessly.
    private static let stepCount = 16
    private static let overshootMargin = 4

    private var savedLevel: Float?

    /// Turns the keyboard backlight fully off, remembering the previous
    /// level (if readable at all) so `restore()` can approximate it.
    func turnOffAndRemember() {
        let current = LidlessGetKeyboardBrightness()
        savedLevel = current >= 0 ? current : nil

        pressIlluminationKey(down: true, times: Self.stepCount + Self.overshootMargin)
    }

    /// Restores the backlight to roughly its previous level. Without a
    /// working getter (the common case on Apple Silicon) this restores to
    /// maximum brightness instead — an visible, working default rather than
    /// leaving the keyboard permanently dark.
    func restore() {
        let presses: Int
        if let savedLevel {
            presses = Int((savedLevel * Float(Self.stepCount)).rounded())
        } else {
            presses = Self.stepCount + Self.overshootMargin
        }
        pressIlluminationKey(down: false, times: presses)
        savedLevel = nil
    }

    private func pressIlluminationKey(down: Bool, times: Int) {
        guard times > 0 else { return }
        // NX_KEYTYPE_ILLUMINATION_DOWN / _UP from <IOKit/hidsystem/ev_keymap.h>.
        let keyCode: Int32 = down ? 22 : 21
        for _ in 0..<times {
            postSystemDefinedKey(keyCode)
            usleep(15_000)
        }
    }

    /// Posts the same NSEvent.systemDefined key-down/key-up pair the
    /// hardware media key itself generates. This exact event shape
    /// (subtype 8, data1 packing the key code and press state) is the
    /// standard, widely-used technique for simulating macOS media keys.
    private func postSystemDefinedKey(_ keyCode: Int32) {
        for isKeyDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: isKeyDown ? 0xa00 : 0xb00)
            let data1 = (Int(keyCode) << 16) | ((isKeyDown ? 0xa : 0xb) << 8)
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { continue }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

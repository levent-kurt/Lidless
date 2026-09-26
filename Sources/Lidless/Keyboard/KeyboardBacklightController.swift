import Foundation

/// Controls the built-in keyboard backlight via CoreBrightness's private
/// KeyboardBrightnessClient class. There is no public API for this; the
/// class, its keyboard-ID enumeration, and its 4-argument setter (fade
/// speed + explicit commit flag, rather than the simpler 2-argument setter
/// that turned out to be a dead no-op on Apple Silicon) are all
/// undocumented, but confirmed working on real hardware.
final class KeyboardBacklightController {

    private static let objcMsgSend: UnsafeMutableRawPointer = {
        guard let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else {
            fatalError("objc_msgSend not found")
        }
        return ptr
    }()

    private typealias CopyIDsFn = @convention(c) (NSObject, Selector) -> Unmanaged<CFArray>?
    private typealias GetBrightnessFn = @convention(c) (NSObject, Selector, UInt64) -> Float
    private typealias SetBrightnessFn = @convention(c) (NSObject, Selector, Float, Int, Bool, UInt64) -> Bool

    private static let copyIDsSelector = Selector(("copyKeyboardBacklightIDs"))
    private static let getBrightnessSelector = Selector(("brightnessForKeyboard:"))
    private static let setBrightnessSelector = Selector(("setBrightness:fadeSpeed:commit:forKeyboard:"))

    private let client: NSObject?
    private var keyboardID: UInt64 = 1
    private var savedBrightness: Float?

    init() {
        guard let bundle = Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework"),
              bundle.load(),
              let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else {
            client = nil
            return
        }
        client = clientClass.init()
    }

    /// Turns the keyboard backlight fully off, remembering the previous
    /// level so `restore()` can put it back.
    func turnOffAndRemember() {
        guard let client else { return }

        let copyIDs = unsafeBitCast(Self.objcMsgSend, to: CopyIDsFn.self)
        if let ids = copyIDs(client, Self.copyIDsSelector)?.takeRetainedValue() as? [AnyObject],
           let firstID = ids.first as? NSNumber {
            keyboardID = firstID.uint64Value
        }

        let getBrightness = unsafeBitCast(Self.objcMsgSend, to: GetBrightnessFn.self)
        let current = getBrightness(client, Self.getBrightnessSelector, keyboardID)
        savedBrightness = current >= 0 ? current : nil

        setBrightness(0.0)
    }

    /// Restores the previously saved backlight level. If nothing was ever
    /// saved (private API unavailable, or no valid level was read), this is
    /// a no-op.
    func restore() {
        guard let savedBrightness else { return }
        setBrightness(savedBrightness)
        self.savedBrightness = nil
    }

    private func setBrightness(_ level: Float) {
        guard let client else { return }
        let setBrightness = unsafeBitCast(Self.objcMsgSend, to: SetBrightnessFn.self)
        _ = setBrightness(client, Self.setBrightnessSelector, level, 0, true, keyboardID)
    }
}

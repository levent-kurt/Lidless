import CoreGraphics
import Foundation

/// Blacks out every connected display by driving its actual hardware
/// brightness to zero via the private DisplayServices framework, instead of
/// covering the screen with an opaque window. Confirmed working on real
/// Apple Silicon hardware.
final class DisplayBrightnessController {

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static let getBrightness: GetBrightnessFn? = {
        guard let handle, let ptr = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(ptr, to: GetBrightnessFn.self)
    }()

    private static let setBrightness: SetBrightnessFn? = {
        guard let handle, let ptr = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(ptr, to: SetBrightnessFn.self)
    }()

    private var savedBrightness: [CGDirectDisplayID: Float] = [:]

    /// Sets every currently active display to 0 brightness, remembering
    /// each one's previous level so `restore()` can put it back.
    func turnOffAndRemember() {
        for displayID in Self.activeDisplayIDs() where savedBrightness[displayID] == nil {
            dimDisplay(displayID)
        }
    }

    /// Dims any display that became active after `turnOffAndRemember()` was
    /// called (e.g. a monitor plugged in mid-session) without touching
    /// displays already dimmed.
    func dimAnyNewDisplays() {
        turnOffAndRemember()
    }

    func restore() {
        for (displayID, level) in savedBrightness {
            _ = Self.setBrightness?(displayID, level)
        }
        savedBrightness.removeAll()
    }

    private func dimDisplay(_ displayID: CGDirectDisplayID) {
        var level: Float = 0
        if let getBrightness = Self.getBrightness, getBrightness(displayID, &level) == 0 {
            savedBrightness[displayID] = level
        }
        _ = Self.setBrightness?(displayID, 0.0)
    }

    private static func activeDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        return displays
    }
}

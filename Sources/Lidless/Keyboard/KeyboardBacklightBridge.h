#ifndef KeyboardBacklightBridge_h
#define KeyboardBacklightBridge_h

#include <stdbool.h>

/// Sets the built-in keyboard backlight brightness (0.0 - 1.0).
///
/// There is no public macOS API for this. Two private mechanisms are tried,
/// in order, and the first one that appears to take effect wins:
///   1. CoreBrightness's "KeyboardBrightnessClient" class (the mechanism
///      System Settings itself used on Intel Macs).
///   2. A raw IOHIDEventSystemClient vendor-defined HID event on the
///      AppleVendor usage page — the mechanism Apple Silicon's keyboard
///      backlight actually responds to.
/// Every step logs to os_log (subsystem "com.leventkurt.Lidless", category
/// "KeyboardBacklight") so failures are diagnosable from Console.app rather
/// than silent. Returns false if neither mechanism worked.
bool LidlessSetKeyboardBrightness(float level);

/// Reads the current keyboard backlight brightness (0.0 - 1.0) via
/// CoreBrightness. Returns a negative value if it could not be read (the
/// HID-event path is write-only, so this only ever reflects mechanism 1).
float LidlessGetKeyboardBrightness(void);

#endif /* KeyboardBacklightBridge_h */

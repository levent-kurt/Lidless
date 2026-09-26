#ifndef KeyboardBacklightBridge_h
#define KeyboardBacklightBridge_h

#include <stdbool.h>

/// Sets the built-in keyboard backlight brightness (0.0 - 1.0).
/// Backed by the private CoreBrightness "KeyboardBrightnessClient" class —
/// there is no public API for this on macOS. Returns false if the private
/// framework/class/selector isn't available (e.g. it changed shape on a
/// future OS release, or the Mac has no keyboard backlight).
bool LidlessSetKeyboardBrightness(float level);

/// Reads the current keyboard backlight brightness (0.0 - 1.0).
/// Returns a negative value if the level could not be read.
float LidlessGetKeyboardBrightness(void);

#endif /* KeyboardBacklightBridge_h */

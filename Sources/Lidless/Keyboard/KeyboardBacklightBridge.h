#ifndef KeyboardBacklightBridge_h
#define KeyboardBacklightBridge_h

/// Reads the current keyboard backlight brightness (0.0 - 1.0) via
/// CoreBrightness's private KeyboardBrightnessClient class — there is no
/// public API for this. Returns a negative value if it could not be read
/// (confirmed to always be the case on Apple Silicon: the class exists and
/// answers, but reports no usable value — this getter is a best-effort
/// bookkeeping aid only).
///
/// Setting the backlight through this same class was tried and confirmed
/// dead on Apple Silicon too (the setter call succeeds but has no effect on
/// the hardware), so it isn't exposed here — see KeyboardBacklightController
/// for the mechanism that actually works: simulating the keyboard's own
/// brightness media key.
float LidlessGetKeyboardBrightness(void);

#endif /* KeyboardBacklightBridge_h */

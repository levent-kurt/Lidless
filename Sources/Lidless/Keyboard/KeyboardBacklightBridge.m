#import "KeyboardBacklightBridge.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <objc/message.h>

// CoreBrightness's KeyboardBrightnessClient class:
//   @interface KeyboardBrightnessClient : NSObject
//   - (float)brightnessForKeyboard:(int)keyboardType;
//   - (BOOL)setBrightness:(float)brightness forKeyboard:(int)keyboardType;
//   @end
// No header ships for it, so it's looked up by name at runtime. Confirmed
// on real Apple Silicon hardware: the class and both selectors resolve
// fine, but brightnessForKeyboard: always returns -1 (no usable value) and
// setBrightness:forKeyboard: always returns YES while having zero effect on
// the actual hardware. Only the getter is exposed here, purely as a
// best-effort hint for KeyboardBacklightController's bookkeeping — the
// setter isn't wired up anywhere since it's confirmed to do nothing.

typedef float (*LidlessGetBrightnessFn)(id, SEL, int);

static const int kLidlessKeyboardType = 0;

static id LidlessKeyboardBrightnessClient(void) {
    static id client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_NOW
        );
        if (!handle) {
            return;
        }
        Class cls = NSClassFromString(@"KeyboardBrightnessClient");
        if (!cls) {
            return;
        }
        client = [[cls alloc] init];
    });
    return client;
}

float LidlessGetKeyboardBrightness(void) {
    id client = LidlessKeyboardBrightnessClient();
    if (!client) {
        return -1.0f;
    }

    SEL selector = NSSelectorFromString(@"brightnessForKeyboard:");
    if (![client respondsToSelector:selector]) {
        return -1.0f;
    }

    LidlessGetBrightnessFn function = (LidlessGetBrightnessFn)[client methodForSelector:selector];
    return function(client, selector, kLidlessKeyboardType);
}

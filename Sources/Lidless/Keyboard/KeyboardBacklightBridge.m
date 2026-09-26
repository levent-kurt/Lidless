#import "KeyboardBacklightBridge.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>

// macOS has no public API for the built-in keyboard backlight. The only
// working mechanism (used by several long-standing open-source utilities)
// is the private CoreBrightness framework's KeyboardBrightnessClient class:
//
//   @interface KeyboardBrightnessClient : NSObject
//   - (float)brightnessForKeyboard:(int)keyboardType;
//   - (BOOL)setBrightness:(float)brightness forKeyboard:(int)keyboardType;
//   @end
//
// Since no header ships for it, we look the class up by name at runtime and
// invoke the selectors through correctly-typed C function pointers (plain
// -performSelector: can't carry a float argument or return type). Everything
// here fails soft: if Apple reshapes or removes this in a future release,
// these functions simply return false / a negative value instead of crashing.

typedef BOOL (*LidlessSetBrightnessFn)(id, SEL, float, int);
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

bool LidlessSetKeyboardBrightness(float level) {
    id client = LidlessKeyboardBrightnessClient();
    if (!client) {
        return false;
    }

    SEL selector = NSSelectorFromString(@"setBrightness:forKeyboard:");
    if (![client respondsToSelector:selector]) {
        return false;
    }

    float clamped = MAX(0.0f, MIN(1.0f, level));
    LidlessSetBrightnessFn function = (LidlessSetBrightnessFn)[client methodForSelector:selector];
    return (bool)function(client, selector, clamped, kLidlessKeyboardType);
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

#import "KeyboardBacklightBridge.h"
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <os/log.h>

// macOS has no public API for the built-in keyboard backlight. Two private
// mechanisms are tried:
//
//   1. CoreBrightness's KeyboardBrightnessClient class — the mechanism
//      System Settings itself used to use, at least on Intel Macs:
//        @interface KeyboardBrightnessClient : NSObject
//        - (float)brightnessForKeyboard:(int)keyboardType;
//        - (BOOL)setBrightness:(float)brightness forKeyboard:(int)keyboardType;
//        @end
//      No header ships for it, so the class/selectors are looked up by name
//      at runtime and invoked through correctly-typed C function pointers
//      (plain -performSelector: can't carry a float argument or return type).
//
//   2. IOHIDServiceClientSetElementValue on Apple's private vendor usage
//      page (0xff00), which is what actually reaches the keyboard backlight
//      controller on Apple Silicon. This API has no public header either,
//      so its C functions are forward-declared below and resolved against
//      IOKit.framework, which Lidless already links.
//
// Both paths log every step via os_log so a failure is diagnosable from
// Console.app (subsystem "com.leventkurt.Lidless", category
// "KeyboardBacklight") instead of silently doing nothing. Neither path is
// guaranteed by Apple, so this is inherently best-effort: if a future macOS
// release reshapes either mechanism, these functions degrade to a no-op
// rather than crashing.

static os_log_t LidlessKeyboardLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.leventkurt.Lidless", "KeyboardBacklight");
    });
    return log;
}

#pragma mark - Mechanism 1: CoreBrightness KeyboardBrightnessClient

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
            os_log_error(LidlessKeyboardLog(), "CoreBrightness: dlopen failed");
            return;
        }
        Class cls = NSClassFromString(@"KeyboardBrightnessClient");
        if (!cls) {
            os_log_error(LidlessKeyboardLog(), "CoreBrightness: KeyboardBrightnessClient class not found");
            return;
        }
        client = [[cls alloc] init];
        os_log(LidlessKeyboardLog(), "CoreBrightness: client %{public}@", client ? @"created" : @"failed to init");
    });
    return client;
}

static bool LidlessSetKeyboardBrightnessViaCoreBrightness(float level) {
    id client = LidlessKeyboardBrightnessClient();
    if (!client) {
        return false;
    }

    SEL selector = NSSelectorFromString(@"setBrightness:forKeyboard:");
    if (![client respondsToSelector:selector]) {
        os_log_error(LidlessKeyboardLog(), "CoreBrightness: client does not respond to setBrightness:forKeyboard:");
        return false;
    }

    LidlessSetBrightnessFn function = (LidlessSetBrightnessFn)[client methodForSelector:selector];
    BOOL result = function(client, selector, level, kLidlessKeyboardType);
    os_log(LidlessKeyboardLog(), "CoreBrightness: setBrightness:%.2f forKeyboard: -> %{public}@", level, result ? @"YES" : @"NO");
    return (bool)result;
}

float LidlessGetKeyboardBrightness(void) {
    id client = LidlessKeyboardBrightnessClient();
    if (!client) {
        return -1.0f;
    }

    SEL selector = NSSelectorFromString(@"brightnessForKeyboard:");
    if (![client respondsToSelector:selector]) {
        os_log_error(LidlessKeyboardLog(), "CoreBrightness: client does not respond to brightnessForKeyboard:");
        return -1.0f;
    }

    LidlessGetBrightnessFn function = (LidlessGetBrightnessFn)[client methodForSelector:selector];
    float result = function(client, selector, kLidlessKeyboardType);
    os_log(LidlessKeyboardLog(), "CoreBrightness: brightnessForKeyboard: -> %.2f", result);
    return result;
}

#pragma mark - Mechanism 2: IOHIDServiceClientSetElementValue

// No public header declares these; they are real, exported IOKit.framework
// symbols (confirmed via `dyld_info -exports` against the running system —
// see the PR discussion) used internally by Apple's own HID stack. This is
// the same private primitive documented techniques use to set the Caps
// Lock LED (kIOHIDServiceCapsLockLEDKey lives on the very same usage page
// in this framework's export list), applied here to the keyboard
// backlight's own vendor-defined HID element instead.
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern void IOHIDServiceClientSetElementValue(
    IOHIDServiceClientRef service,
    uint32_t usagePage,
    uint32_t usage,
    CFIndex value
);

// Apple's private "AppleVendor" HID usage page, and the usage on it that
// the keyboard backlight controller listens for.
static const uint32_t kLidlessHIDPageAppleVendor = 0xff00;
static const uint32_t kLidlessHIDUsageKeyboardBacklight = 0x0f;

static bool LidlessSetKeyboardBrightnessViaHIDElement(float level) {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) {
        os_log_error(LidlessKeyboardLog(), "HIDElement: IOHIDEventSystemClientCreate failed");
        return false;
    }

    NSDictionary *matching = @{
        @"PrimaryUsagePage": @(kLidlessHIDPageAppleVendor),
        @"PrimaryUsage": @(kLidlessHIDUsageKeyboardBacklight),
    };
    IOHIDEventSystemClientSetMatching(client, (__bridge CFDictionaryRef)matching);

    CFArrayRef servicesRef = IOHIDEventSystemClientCopyServices(client);
    NSArray *services = (__bridge_transfer NSArray *)servicesRef;
    os_log(LidlessKeyboardLog(), "HIDElement: matched %lu service(s) on page 0x%x usage 0x%x",
           (unsigned long)services.count, kLidlessHIDPageAppleVendor, kLidlessHIDUsageKeyboardBacklight);

    if (services.count == 0) {
        CFRelease(client);
        return false;
    }

    CFIndex value = (CFIndex)(level * 100.0f);
    for (id serviceObject in services) {
        IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)serviceObject;
        IOHIDServiceClientSetElementValue(service, kLidlessHIDPageAppleVendor, kLidlessHIDUsageKeyboardBacklight, value);
    }

    CFRelease(client);
    os_log(LidlessKeyboardLog(), "HIDElement: set value %ld on %lu service(s)", (long)value, (unsigned long)services.count);
    return true;
}

#pragma mark - Public entry point

bool LidlessSetKeyboardBrightness(float level) {
    float clamped = MAX(0.0f, MIN(1.0f, level));

    bool coreBrightnessOK = LidlessSetKeyboardBrightnessViaCoreBrightness(clamped);
    bool hidElementOK = LidlessSetKeyboardBrightnessViaHIDElement(clamped);

    return coreBrightnessOK || hidElementOK;
}

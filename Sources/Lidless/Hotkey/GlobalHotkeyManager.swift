import Carbon
import AppKit

/// Registers a single system-wide keyboard shortcut using Carbon's
/// RegisterEventHotKey. This still works fine in a modern Swift/AppKit app
/// (Carbon.HIToolbox is just a header shim at this point) and, unlike a
/// CGEventTap, it requires no special permission and works even while
/// another app has full keyboard focus.
final class GlobalHotkeyManager {

    private static let signature: OSType = {
        // Any 4-byte, non-zero value uniquely identifying this app's hotkeys.
        let bytes: [UInt8] = Array("LDLS".utf8)
        return bytes.reduce(OSType(0)) { ($0 << 8) | OSType($1) }
    }()

    private let preferences: PreferencesStore
    private let onInvoke: () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(preferences: PreferencesStore, onInvoke: @escaping () -> Void) {
        self.preferences = preferences
        self.onInvoke = onInvoke
        installEventHandlerIfNeeded()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if hotKeyID.signature == GlobalHotkeyManager.signature {
                    DispatchQueue.main.async {
                        manager.onInvoke()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    func registerCurrentShortcut() {
        register(preferences.hotkeyShortcut)
    }

    func register(_ combo: KeyCombo) {
        unregister()

        var newHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: GlobalHotkeyManager.signature, id: 1)

        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &newHotKeyRef
        )

        if status == noErr {
            hotKeyRef = newHotKeyRef
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

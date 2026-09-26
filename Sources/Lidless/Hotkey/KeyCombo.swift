import Carbon
import AppKit

/// A persistable (keyCode, modifiers) pair describing a global shortcut.
/// Modifiers are stored as Carbon modifier masks (cmdKey/optionKey/etc.)
/// since that's what RegisterEventHotKey needs; the recorder UI converts
/// NSEvent modifier flags to/from this representation.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    /// Cmd+F6 — chosen because F6 has no common system-wide meaning on
    /// modern Macs and Cmd+F6 doesn't collide with Mission Control, Spotlight,
    /// or other default macOS shortcuts.
    static let defaultShortcut = KeyCombo(keyCode: UInt32(kVK_F6), carbonModifiers: UInt32(cmdKey))

    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += KeyCombo.keyName(for: keyCode)
        return result
    }

    static func from(event: NSEvent) -> KeyCombo {
        var carbonModifiers: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        return KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: carbonModifiers)
    }

    private static func keyName(for keyCode: UInt32) -> String {
        let functionKeyNames: [UInt32: String] = [
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
            UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
            UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
            UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        ]
        if let name = functionKeyNames[keyCode] {
            return name
        }

        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue() as Data
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0

            let status = layoutData.withUnsafeBytes { rawBuffer -> OSStatus in
                guard let keyboardLayoutPointer = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                    return OSStatus(paramErr)
                }
                return UCKeyTranslate(
                    keyboardLayoutPointer,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )
            }

            if status == noErr, length > 0 {
                return String(utf16CodeUnits: chars, count: length).uppercased()
            }
        }

        return "Key \(keyCode)"
    }
}

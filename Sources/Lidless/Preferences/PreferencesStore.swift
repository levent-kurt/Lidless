import Combine
import Foundation

/// UserDefaults-backed, observable source of truth for every user-facing
/// setting. A single shared instance is used app-wide so the status bar,
/// preferences window, hotkey manager, and blackout controller all react to
/// the same state.
final class PreferencesStore: ObservableObject {

    static let shared = PreferencesStore()

    private enum Keys {
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let minimumKeystrokes = "minimumKeystrokes"
        static let mouseMovementDurationSeconds = "mouseMovementDurationSeconds"
        static let mouseMovementDistancePixels = "mouseMovementDistancePixels"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults

    @Published var hotkeyShortcut: KeyCombo {
        didSet {
            defaults.set(hotkeyShortcut.keyCode, forKey: Keys.hotkeyKeyCode)
            defaults.set(hotkeyShortcut.carbonModifiers, forKey: Keys.hotkeyModifiers)
        }
    }

    /// 1...5, default 3.
    @Published var minimumKeystrokes: Int {
        didSet { defaults.set(minimumKeystrokes, forKey: Keys.minimumKeystrokes) }
    }

    /// Seconds of continuous mouse movement required to wake, default 2.0.
    @Published var mouseMovementDurationSeconds: Double {
        didSet { defaults.set(mouseMovementDurationSeconds, forKey: Keys.mouseMovementDurationSeconds) }
    }

    /// Cumulative pixel distance that also wakes regardless of duration, default 120.
    @Published var mouseMovementDistancePixels: Double {
        didSet { defaults.set(mouseMovementDistancePixels, forKey: Keys.mouseMovementDistancePixels) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    var eventTapThresholds: EventTapMonitor.Thresholds {
        EventTapMonitor.Thresholds(
            minimumKeystrokes: minimumKeystrokes,
            mouseMovementDurationSeconds: mouseMovementDurationSeconds,
            mouseMovementDistancePixels: mouseMovementDistancePixels
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.hotkeyKeyCode) != nil {
            hotkeyShortcut = KeyCombo(
                keyCode: UInt32(defaults.integer(forKey: Keys.hotkeyKeyCode)),
                carbonModifiers: UInt32(defaults.integer(forKey: Keys.hotkeyModifiers))
            )
        } else {
            hotkeyShortcut = .defaultShortcut
        }

        minimumKeystrokes = defaults.object(forKey: Keys.minimumKeystrokes) != nil
            ? defaults.integer(forKey: Keys.minimumKeystrokes)
            : 3

        mouseMovementDurationSeconds = defaults.object(forKey: Keys.mouseMovementDurationSeconds) != nil
            ? defaults.double(forKey: Keys.mouseMovementDurationSeconds)
            : 2.0

        mouseMovementDistancePixels = defaults.object(forKey: Keys.mouseMovementDistancePixels) != nil
            ? defaults.double(forKey: Keys.mouseMovementDistancePixels)
            : 120.0

        // Reflect the real SMAppService status rather than trusting a stale
        // default, in case the user changed it from System Settings directly.
        launchAtLogin = LaunchAtLoginManager.isEnabled
    }
}

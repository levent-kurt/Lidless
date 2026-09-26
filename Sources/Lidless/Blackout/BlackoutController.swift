import AppKit
import Combine
import CoreGraphics

/// Orchestrates a single Blackout Mode session: every display's hardware
/// brightness driven to zero, a power assertion so background tasks keep
/// running, the keyboard backlight going dark, and the event-tap "wake up"
/// watchdog.
final class BlackoutController: ObservableObject {

    @Published private(set) var isActive = false

    private let preferences: PreferencesStore
    private let powerAssertionManager = PowerAssertionManager()
    private let keyboardBacklightController = KeyboardBacklightController()
    private let displayBrightnessController = DisplayBrightnessController()
    private var eventTapMonitor: EventTapMonitor?

    private var savedCursorPosition: CGPoint?
    private var screenChangeObserver: NSObjectProtocol?
    private var preferencesCancellable: AnyCancellable?

    init(preferences: PreferencesStore) {
        self.preferences = preferences

        preferencesCancellable = Publishers.CombineLatest3(
            preferences.$minimumKeystrokes,
            preferences.$mouseMovementDurationSeconds,
            preferences.$mouseMovementDistancePixels
        )
        .sink { [weak self] minimumKeystrokes, duration, distance in
            self?.eventTapMonitor?.updateThresholds(
                EventTapMonitor.Thresholds(
                    minimumKeystrokes: minimumKeystrokes,
                    mouseMovementDurationSeconds: duration,
                    mouseMovementDistancePixels: distance
                )
            )
        }
    }

    func toggle() {
        isActive ? stop() : start()
    }

    func start() {
        guard !isActive else { return }
        isActive = true

        hideCursor()
        displayBrightnessController.turnOffAndRemember()
        observeScreenChanges()

        powerAssertionManager.acquire(reason: "Lidless Blackout Mode is active")
        keyboardBacklightController.turnOffAndRemember()

        let monitor = EventTapMonitor(thresholds: preferences.eventTapThresholds) { [weak self] in
            self?.stop()
        }
        eventTapMonitor = monitor
        monitor.start()
    }

    func stop() {
        guard isActive else { return }
        isActive = false

        eventTapMonitor?.stop()
        eventTapMonitor = nil

        stopObservingScreenChanges()

        keyboardBacklightController.restore()
        powerAssertionManager.release()

        displayBrightnessController.restore()
        showCursor()
    }

    /// Synchronous teardown for app termination — no animations, no delays.
    func forceStopImmediately() {
        guard isActive else { return }
        stop()
    }

    private func hideCursor() {
        savedCursorPosition = CGEvent(source: nil)?.location
        CGDisplayHideCursor(kCGNullDirectDisplay)
    }

    private func showCursor() {
        if let savedCursorPosition {
            CGWarpMouseCursorPosition(savedCursorPosition)
        }
        savedCursorPosition = nil
        CGDisplayShowCursor(kCGNullDirectDisplay)
    }

    private func observeScreenChanges() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.displayBrightnessController.dimAnyNewDisplays()
        }
    }

    private func stopObservingScreenChanges() {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        screenChangeObserver = nil
    }
}

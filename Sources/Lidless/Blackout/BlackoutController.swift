import AppKit
import Combine

/// Orchestrates a single Blackout Mode session: overlay windows on every
/// display, a power assertion so background tasks keep running, the
/// keyboard backlight going dark, and the event-tap "wake up" watchdog.
final class BlackoutController: ObservableObject {

    @Published private(set) var isActive = false

    private let preferences: PreferencesStore
    private let powerAssertionManager = PowerAssertionManager()
    private let keyboardBacklightController = KeyboardBacklightController()
    private var eventTapMonitor: EventTapMonitor?

    private var overlayWindows: [OverlayWindow] = []
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

        createOverlayWindows()
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
        removeOverlayWindows()

        keyboardBacklightController.restore()
        powerAssertionManager.release()
    }

    /// Synchronous teardown for app termination — no animations, no delays.
    func forceStopImmediately() {
        guard isActive else { return }
        stop()
    }

    private func createOverlayWindows() {
        overlayWindows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            window.show()
            return window
        }
    }

    private func removeOverlayWindows() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    private func observeScreenChanges() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.removeOverlayWindows()
            self.createOverlayWindows()
        }
    }

    private func stopObservingScreenChanges() {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        screenChangeObserver = nil
    }
}

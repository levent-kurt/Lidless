import AppKit
import Combine
import CoreGraphics

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
        // NSCursor.hide() is tied to app/window focus and gets reset by the
        // window server on the next mouse-moved event regardless — it does
        // not survive real trackpad/mouse movement. CGDisplayHideCursor
        // operates at the display/session level and stays hidden through
        // movement, which is what "invisible during Blackout" needs.
        CGDisplayHideCursor(kCGDirectMainDisplay)

        powerAssertionManager.acquire(reason: "Lidless Blackout Mode is active")
        // Turning the backlight off simulates the brightness media key,
        // which shows the system's on-screen HUD — done after the overlay
        // is already up so that HUD ends up hidden underneath it.
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

        // Restore the backlight (and release the cursor/overlay) while the
        // overlay is still up — restoring simulates the brightness media
        // key too, which shows the system's on-screen HUD, and the overlay
        // sitting above it is what keeps that HUD from being visible.
        keyboardBacklightController.restore()
        powerAssertionManager.release()

        removeOverlayWindows()
        CGDisplayShowCursor(kCGDirectMainDisplay)
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

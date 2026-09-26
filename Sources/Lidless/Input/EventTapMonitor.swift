import AppKit
import CoreGraphics

/// Listens system-wide for keyboard and mouse activity while Blackout Mode
/// is active, and calls back once the user's configured "wake" threshold is
/// crossed. Uses a listen-only CGEventTap so it never interferes with the
/// events themselves — the overlay windows already ignore mouse events, and
/// this tap does not consume or alter anything.
final class EventTapMonitor {

    struct Thresholds {
        var minimumKeystrokes: Int
        var mouseMovementDurationSeconds: TimeInterval
        var mouseMovementDistancePixels: Double
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var thresholds: Thresholds
    private let onThresholdReached: () -> Void

    private var keystrokeCount = 0
    private var cumulativeMouseDistance: Double = 0
    private var movementStreakStart: CFAbsoluteTime?
    private var lastMouseEventTime: CFAbsoluteTime = 0

    /// Gap larger than this resets a "continuous movement" streak.
    private let movementStreakGapTolerance: CFAbsoluteTime = 0.35

    init(thresholds: Thresholds, onThresholdReached: @escaping () -> Void) {
        self.thresholds = thresholds
        self.onThresholdReached = onThresholdReached
    }

    func updateThresholds(_ thresholds: Thresholds) {
        self.thresholds = thresholds
    }

    func start() {
        resetCounters()

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<EventTapMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            // Most likely missing Accessibility / Input Monitoring permission.
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        resetCounters()
    }

    private func resetCounters() {
        keystrokeCount = 0
        cumulativeMouseDistance = 0
        movementStreakStart = nil
        lastMouseEventTime = 0
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        switch type {
        case .keyDown:
            handleKeyDown()
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            handleMouseMoved(event: event)
        default:
            break
        }
    }

    private func handleKeyDown() {
        keystrokeCount += 1
        if keystrokeCount >= max(1, thresholds.minimumKeystrokes) {
            fireThresholdReached()
        }
    }

    private func handleMouseMoved(event: CGEvent) {
        let now = CFAbsoluteTimeGetCurrent()
        let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY = event.getDoubleValueField(.mouseEventDeltaY)
        let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()

        cumulativeMouseDistance += distance

        if movementStreakStart == nil || (now - lastMouseEventTime) > movementStreakGapTolerance {
            movementStreakStart = now
        }
        lastMouseEventTime = now

        let streakDuration = now - (movementStreakStart ?? now)

        let distanceThresholdMet = thresholds.mouseMovementDistancePixels > 0
            && cumulativeMouseDistance >= thresholds.mouseMovementDistancePixels
        let durationThresholdMet = thresholds.mouseMovementDurationSeconds > 0
            && streakDuration >= thresholds.mouseMovementDurationSeconds

        if distanceThresholdMet || durationThresholdMet {
            fireThresholdReached()
        }
    }

    private func fireThresholdReached() {
        // Stop listening immediately so we only fire once per Blackout
        // session; BlackoutController will call start() again next time.
        stop()
        DispatchQueue.main.async { [onThresholdReached] in
            onThresholdReached()
        }
    }
}

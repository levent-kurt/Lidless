import IOKit
import IOKit.pwr_mgt

/// Wraps IOPMAssertionCreateWithName so the Mac keeps its CPU, GPU, and
/// network fully active (no idle sleep, no display sleep) while the overlay
/// is covering the screen — background jobs must keep running.
final class PowerAssertionManager {

    private var systemSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0
    private var isHolding = false

    func acquire(reason: String) {
        guard !isHolding else { return }

        var systemID: IOPMAssertionID = 0
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &systemID
        )

        var displayID: IOPMAssertionID = 0
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &displayID
        )

        if systemResult == kIOReturnSuccess {
            systemSleepAssertionID = systemID
        }
        if displayResult == kIOReturnSuccess {
            displaySleepAssertionID = displayID
        }

        isHolding = systemResult == kIOReturnSuccess || displayResult == kIOReturnSuccess
    }

    func release() {
        guard isHolding else { return }

        if systemSleepAssertionID != 0 {
            IOPMAssertionRelease(systemSleepAssertionID)
            systemSleepAssertionID = 0
        }
        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
            displaySleepAssertionID = 0
        }
        isHolding = false
    }

    deinit {
        release()
    }
}

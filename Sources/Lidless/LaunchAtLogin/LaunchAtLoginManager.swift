import ServiceManagement

/// Thin wrapper around SMAppService (macOS 13+) for the "Launch at Login"
/// preference toggle.
enum LaunchAtLoginManager {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Best-effort: if registration fails (e.g. the user removed it
            // from System Settings' Login Items list directly), the toggle
            // will simply reflect the real status next time it's read.
        }
    }
}

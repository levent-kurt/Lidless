import SwiftUI

@main
struct LidlessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Lidless never shows a normal window; the empty Settings scene keeps
        // SwiftUI's app lifecycle happy without creating any visible UI.
        // LSUIElement (Info.plist) + NSApp.setActivationPolicy(.accessory)
        // (AppDelegate) keep it out of the Dock and Cmd+Tab switcher.
        Settings {
            EmptyView()
        }
    }
}

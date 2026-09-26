import SwiftUI

struct PreferencesView: View {
    @ObservedObject var preferences: PreferencesStore
    let hotkeyManager: GlobalHotkeyManager?

    @State private var isAccessibilityTrusted = PermissionsManager.shared.isAccessibilityTrusted()

    var body: some View {
        Form {
            Section("Global Shortcut") {
                HStack {
                    Text("Toggle Blackout Mode")
                    Spacer()
                    HotkeyRecorderView(combo: $preferences.hotkeyShortcut) { newCombo in
                        hotkeyManager?.register(newCombo)
                    }
                    .frame(width: 160, height: 24)
                }
            }

            Section("Wake-Up Sensitivity") {
                VStack(alignment: .leading) {
                    Text("Minimum keystrokes to wake: \(preferences.minimumKeystrokes)")
                    Slider(
                        value: Binding(
                            get: { Double(preferences.minimumKeystrokes) },
                            set: { preferences.minimumKeystrokes = Int($0.rounded()) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                }

                VStack(alignment: .leading) {
                    Text("Continuous mouse movement to wake: \(preferences.mouseMovementDurationSeconds, specifier: "%.1f")s")
                    Slider(
                        value: $preferences.mouseMovementDurationSeconds,
                        in: 0.5...5.0,
                        step: 0.5
                    )
                }

                VStack(alignment: .leading) {
                    Text("Or total mouse movement to wake: \(Int(preferences.mouseMovementDistancePixels)) px")
                    Slider(
                        value: $preferences.mouseMovementDistancePixels,
                        in: 20...500,
                        step: 10
                    )
                }
            }

            Section("General") {
                Toggle("Launch Lidless at Login", isOn: $preferences.launchAtLogin)

                HStack {
                    Circle()
                        .fill(isAccessibilityTrusted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(isAccessibilityTrusted ? "Accessibility permission granted" : "Accessibility permission missing")
                    Spacer()
                    Button("Recheck") {
                        isAccessibilityTrusted = PermissionsManager.shared.isAccessibilityTrusted()
                    }
                    if !isAccessibilityTrusted {
                        Button("Open Settings") {
                            PermissionsManager.shared.openAccessibilitySettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
        .onAppear {
            isAccessibilityTrusted = PermissionsManager.shared.isAccessibilityTrusted()
        }
    }
}

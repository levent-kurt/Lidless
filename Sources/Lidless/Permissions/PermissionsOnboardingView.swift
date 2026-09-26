import SwiftUI

struct PermissionsOnboardingView: View {
    let onOpenSettings: () -> Void
    let onRequestPrompt: () -> Void
    let onRecheck: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("Accessibility Permission Needed")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text("""
            Lidless watches for keyboard and mouse activity so it knows when \
            to end Blackout Mode and turn your screen back on. macOS requires \
            Accessibility permission for this kind of system-wide monitoring.
            """)
            .fixedSize(horizontal: false, vertical: true)

            Text("""
            Without this permission, Blackout Mode can still be started, but \
            it will only be possible to exit it by force-quitting Lidless.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Open System Settings") {
                    onRequestPrompt()
                    onOpenSettings()
                }
                .keyboardShortcut(.defaultAction)

                Button("I've granted it — recheck") {
                    onRecheck()
                }

                Spacer()

                Button("Not Now") {
                    onDismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

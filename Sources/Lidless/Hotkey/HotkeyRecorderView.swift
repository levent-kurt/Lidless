import SwiftUI
import AppKit

/// A click-to-record field for a global shortcut: click it, press a key
/// combo, and it captures the combo (as long as it includes at least one
/// modifier) and hands it back via `onChange`.
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var combo: KeyCombo
    var onChange: (KeyCombo) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = { newCombo in
            combo = newCombo
            onChange(newCombo)
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.displayString = combo.displayString
    }

    final class RecorderNSView: NSView {
        var onCapture: ((KeyCombo) -> Void)?
        var displayString: String = "" {
            didSet { needsDisplay = true }
        }

        private var isRecording = false {
            didSet { needsDisplay = true }
        }

        override var acceptsFirstResponder: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: 160, height: 24)
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isRecording = true
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }

            // Require at least one modifier so the recorded shortcut can't
            // collide with ordinary typing once it's active system-wide.
            let hasModifier = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty == false
            guard hasModifier, event.keyCode != 53 /* Escape cancels */ else {
                if event.keyCode == 53 {
                    isRecording = false
                    window?.makeFirstResponder(nil)
                }
                return
            }

            let combo = KeyCombo.from(event: event)
            onCapture?(combo)
            isRecording = false
            window?.makeFirstResponder(nil)
        }

        override func draw(_ dirtyRect: NSRect) {
            let backgroundColor: NSColor = isRecording ? .controlAccentColor.withAlphaComponent(0.15) : .controlBackgroundColor
            backgroundColor.setFill()
            let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
            path.fill()

            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()

            let text = isRecording ? "Type shortcut…" : displayString
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13),
            ]
            let size = text.size(withAttributes: attributes)
            let origin = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
            text.draw(at: origin, withAttributes: attributes)
        }
    }
}

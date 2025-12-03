import SwiftUI
import AppKit

struct ShortcutRecorderField: View {
    @Binding var value: KeyboardShortcut?
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            RecorderRepresentable(value: $value, placeholder: placeholder)
                .frame(height: 24)
        }
    }

    private struct RecorderRepresentable: NSViewRepresentable {
        @Binding var value: KeyboardShortcut?
        var placeholder: String

        func makeNSView(context: Context) -> RecorderView {
            let v = RecorderView()
            v.updateBinding = { self.value = $0 }
            v.placeholder = placeholder
            v.shortcut = value
            return v
        }

        func updateNSView(_ nsView: RecorderView, context: Context) {
            nsView.shortcut = value
            nsView.placeholder = placeholder
            nsView.needsDisplay = true
        }
    }

    private final class RecorderView: NSView {
        var updateBinding: ((KeyboardShortcut?) -> Void)?
        var placeholder: String = ""
        var shortcut: KeyboardShortcut? { didSet { needsDisplay = true } }
        private var isRecording: Bool = false {
            didSet {
                needsDisplay = true
                // 录制快捷键时暂停现有快捷键触发，避免冲突
                if isRecording {
                    Task { @MainActor in
                        HotkeyManager.shared.suspendHotkeys()
                    }
                } else {
                    Task { @MainActor in
                        HotkeyManager.shared.resumeHotkeys()
                    }
                }
            }
        }

        override var acceptsFirstResponder: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            NSColor.controlBackgroundColor.setFill()
            path.fill()
            (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = isRecording ? 2 : 1
            path.stroke()

            let text = shortcut?.displayText ?? (isRecording ? "…" : placeholder)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor
            ]
            let size = (text as NSString).size(withAttributes: attributes)
            let rect = NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
            (text as NSString).draw(in: rect, withAttributes: attributes)
        }

        override func mouseDown(with event: NSEvent) {
            isRecording = true
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else { return }
            if event.keyCode == 51 { // delete to clear
                shortcut = nil
                updateBinding?(nil)
                isRecording = false
                return
            }
            if let sc = KeyboardShortcut(event: event) {
                shortcut = sc
                updateBinding?(sc)
                isRecording = false
            }
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            return super.resignFirstResponder()
        }
    }
}

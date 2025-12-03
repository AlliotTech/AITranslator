import SwiftUI
import AppKit
import ObjectiveC

final class FocusAwareTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        onFocusChange?(true)
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        onFocusChange?(false)
        return ok
    }
}

struct PlaceholderTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    // Sending behavior
    var sendOnEnter: Bool = false
    var onSubmit: (() -> Void)? = nil
    // Callback when user pastes into the text view
    var onExternalPaste: (() -> Void)? = nil
    // Token-based force focus: when this changes to non-zero, force claiming first responder
    // even if another NSTextView is currently focused (used for explicit show-window focus)
    var forceFocusToken: Int = 0
    var font: NSFont = .preferredFont(forTextStyle: .body)
    var textColor: NSColor = .labelColor
    var placeholderColor: NSColor = .secondaryLabelColor
    var textContainerInset: NSSize = NSSize(width: 8, height: 8)
    var lineFragmentPadding: CGFloat = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = FocusAwareTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = textContainerInset
        textView.textContainer?.lineFragmentPadding = lineFragmentPadding
        if let container = textView.textContainer {
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }

        // Placeholder label
        let placeholderLabel = NSTextField(labelWithString: placeholder)
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.font = font
        placeholderLabel.isHidden = !text.isEmpty
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: textContainerInset.width + lineFragmentPadding),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: textContainerInset.height)
        ])

        context.coordinator.textView = textView
        context.coordinator.placeholderLabel = placeholderLabel

        textView.string = text

        textView.onFocusChange = { focused in
            context.coordinator.handleFocusChange(focused)
        }
        // Configure submit behavior
        textView.shouldSendOnEnter = sendOnEnter
        textView.onSubmit = { self.onSubmit?() }
        // Configure paste callback
        textView.onExternalPaste = { self.onExternalPaste?() }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = textContainerInset
        textView.textContainer?.lineFragmentPadding = lineFragmentPadding
        if let container = textView.textContainer {
            let width = nsView.contentView.documentVisibleRect.width
            container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }

        if let label = context.coordinator.placeholderLabel {
            label.stringValue = placeholder
            label.font = font
            label.textColor = placeholderColor
            label.isHidden = !text.isEmpty
        }

        // Sync focus state from SwiftUI to AppKit
        if let window = nsView.window {
            let isFirstResponder = (window.firstResponder as AnyObject?) === textView

            // Check if force focus token changed (and is non-zero)
            let shouldForceFocus = forceFocusToken != 0 &&
                                   forceFocusToken != context.coordinator.lastProcessedForceFocusToken

            if shouldForceFocus {
                // Force focus was requested via token change
                // Update tracking immediately to avoid reprocessing
                context.coordinator.lastProcessedForceFocusToken = forceFocusToken

                // Claim first responder with retry to handle window activation delays
                let attemptFocus = {
                    if (window.firstResponder as AnyObject?) !== textView {
                        window.makeFirstResponder(textView)
                    }
                }

                // Immediate attempt
                attemptFocus()

                // Delayed retry to handle window not yet being key
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    attemptFocus()
                }
            } else if isFocused && !isFirstResponder {
                // Normal focus request (not forced)
                if window.isKeyWindow {
                    // Only claim focus if window is key and no other text view has focus
                    if let frText = window.firstResponder as? NSTextView, (frText as AnyObject) !== textView {
                        // Another text view has focus; align binding to avoid UI mismatch
                        context.coordinator.handleFocusChange(false)
                    } else {
                        DispatchQueue.main.async {
                            window.makeFirstResponder(textView)
                        }
                    }
                }
            } else if !isFocused && isFirstResponder {
                // Blur requested
                DispatchQueue.main.async {
                    window.makeFirstResponder(nil)
                }
            }
        }
        // Keep submit behavior updated
        textView.shouldSendOnEnter = sendOnEnter
        textView.onSubmit = { self.onSubmit?() }
        // Keep paste callback updated
        textView.onExternalPaste = { self.onExternalPaste?() }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlaceholderTextEditor
        weak var textView: FocusAwareTextView?
        weak var placeholderLabel: NSTextField?
        // Track the last processed force focus token to detect changes
        var lastProcessedForceFocusToken: Int = 0

        init(_ parent: PlaceholderTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            placeholderLabel?.isHidden = !tv.string.isEmpty
        }

        func handleFocusChange(_ focused: Bool) {
            // Only mirror actual focus to the binding; do not auto-refocus here.
            if parent.isFocused != focused {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.parent.isFocused != focused {
                        self.parent.isFocused = focused
                    }
                }
            }
        }
    }
}

extension FocusAwareTextView {
    // Sending configuration
    private struct Assoc {
        static var sendOnEnterKey: UInt8 = 0
        static var onSubmitKey: UInt8 = 0
        static var onExternalPasteKey: UInt8 = 0
    }
    var shouldSendOnEnter: Bool {
        get { (objc_getAssociatedObject(self, &Assoc.sendOnEnterKey) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &Assoc.sendOnEnterKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var onSubmit: (() -> Void)? {
        get { objc_getAssociatedObject(self, &Assoc.onSubmitKey) as? (() -> Void) }
        set { objc_setAssociatedObject(self, &Assoc.onSubmitKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
    var onExternalPaste: (() -> Void)? {
        get { objc_getAssociatedObject(self, &Assoc.onExternalPasteKey) as? (() -> Void) }
        set { objc_setAssociatedObject(self, &Assoc.onExternalPasteKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }

    override func keyDown(with event: NSEvent) {
        // keyCode: 36 = Return, 76 = Keypad Enter
        if shouldSendOnEnter, (event.keyCode == 36 || event.keyCode == 76) {
            // If the user is composing text via an IME (has marked text),
            // do not treat Enter as submit. Let the IME handle it.
            if self.hasMarkedText() {
                super.keyDown(with: event)
                return
            }
            let flags = event.modifierFlags
            let isShift = flags.contains(.shift)
            let isCommand = flags.contains(.command)
            // In Enter-to-send mode:
            // - Plain Enter sends
            // - Shift+Enter inserts newline
            // - Cmd+Enter should not send (reserved for the other mode)
            if !isShift && !isCommand {
                onSubmit?()
                // prevent newline insertion
                return
            }
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        super.paste(sender)
        onExternalPaste?()
    }
}

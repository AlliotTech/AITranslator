import AppKit
import Carbon
import Foundation

@MainActor
final class HotkeyManager: HotkeyManaging {
    static let shared = HotkeyManager()

    struct Defaults {
        static let showHide = KeyboardShortcut(keyCode: 13, carbonModifiers: UInt32(cmdKey | shiftKey)) // ⌘⇧W
        static let toggleMode = KeyboardShortcut(keyCode: 46, carbonModifiers: UInt32(controlKey | optionKey)) // ⌃⌥M
        static let quickCopy = KeyboardShortcut(keyCode: 8, carbonModifiers: UInt32(controlKey | optionKey)) // ⌃⌥C
        static let screenshotOCR = KeyboardShortcut(keyCode: 31, carbonModifiers: UInt32(controlKey | optionKey)) // ⌃⌥O
    }

    enum Action: UInt32 {
        case showWindow = 1
        case toggleMode = 2
        case quickCopy = 3
        case screenshotOCR = 4
    }

    private var eventHandler: EventHandlerRef?
    private var showRef: EventHotKeyRef?
    private var toggleRef: EventHotKeyRef?
    private var copyRef: EventHotKeyRef?
    private var screenshotRef: EventHotKeyRef?
    private var localToggleMonitor: Any?
    private var localQuickCopyMonitor: Any?

    /// 标志位：是否正在录制快捷键（录制时暂停快捷键触发）
    private var isRecordingShortcut: Bool = false

    var onShowWindow: (() -> Void)?
    var onToggleMode: (() -> Void)?
    var onQuickCopy: (() -> Void)?
    var onScreenshotOCR: (() -> Void)?

    private init() {
        installHandlerIfNeeded()
    }

    func apply(show: KeyboardShortcut?, toggle: KeyboardShortcut?, copy: KeyboardShortcut?, screenshotOCR: KeyboardShortcut?) {
        unregisterAll()
        if let showShortcut = show { register(shortcut: showShortcut, action: .showWindow, storeIn: &showRef) }
        if let toggleShortcut = toggle {
            localToggleMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                // 录制快捷键时不触发
                if self.isRecordingShortcut { return event }

                if !event.isARepeat,
                    UInt32(event.keyCode) == toggleShortcut.keyCode,
                    KeyboardShortcut.carbonFlags(from: event.modifierFlags) == toggleShortcut.carbonModifiers {
                    self.onToggleMode?()
                    return nil
                }
                return event
            }
        }
        if let copyShortcut = copy {
            localQuickCopyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                // 录制快捷键时不触发
                if self.isRecordingShortcut { return event }

                if !event.isARepeat,
                    UInt32(event.keyCode) == copyShortcut.keyCode,
                    KeyboardShortcut.carbonFlags(from: event.modifierFlags) == copyShortcut.carbonModifiers {
                    self.onQuickCopy?()
                    return nil
                }
                return event
            }
        }
        if let screenshotShortcut = screenshotOCR {
            register(shortcut: screenshotShortcut, action: .screenshotOCR, storeIn: &screenshotRef)
        }
    }

    func unregisterAll() {
        if let hotKeyRef = showRef { UnregisterEventHotKey(hotKeyRef) }
        if let hotKeyRef = toggleRef { UnregisterEventHotKey(hotKeyRef) }
        if let hotKeyRef = copyRef { UnregisterEventHotKey(hotKeyRef) }
        if let hotKeyRef = screenshotRef { UnregisterEventHotKey(hotKeyRef) }
        if let monitor = localToggleMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localQuickCopyMonitor { NSEvent.removeMonitor(monitor) }
        showRef = nil
        toggleRef = nil
        copyRef = nil
        screenshotRef = nil
        localQuickCopyMonitor = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, eventRef, _ in
            guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status != noErr { return status }

            let action = HotkeyManager.Action(rawValue: hotKeyID.id)
            let manager = HotkeyManager.shared

            // 录制快捷键时不触发
            if manager.isRecordingShortcut { return noErr }

            switch action {
            case .showWindow: manager.onShowWindow?()
            case .toggleMode: manager.onToggleMode?()
            case .quickCopy: manager.onQuickCopy?()
            case .screenshotOCR: manager.onScreenshotOCR?()
            case .none: break
            }
            return noErr
        }
        let status = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventSpec, nil, &eventHandler)
        if status != noErr {
            // Failed to install handler; continue without global hotkeys
        }
    }

    private func register(shortcut: KeyboardShortcut, action: Action, storeIn storage: inout EventHotKeyRef?) {
        let hotKeyID = EventHotKeyID(signature: OSType("AITR".utf8.reduce(0) { ($0 << 8) + OSType($1) }), id: action.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode), UInt32(shortcut.carbonModifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { storage = ref } else { storage = nil }
    }

    // MARK: - Suspend/Resume for Shortcut Recording

    /// 暂停快捷键功能（用于录制快捷键时避免触发现有快捷键）
    func suspendHotkeys() {
        isRecordingShortcut = true
    }

    /// 恢复快捷键功能
    func resumeHotkeys() {
        isRecordingShortcut = false
    }
}

import Foundation
import AppKit
import Carbon

struct KeyboardShortcut: Codable, Equatable, Identifiable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    var id: String { "\(keyCode)-\(carbonModifiers)" }

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(event: NSEvent) {
        let code = UInt32(event.keyCode)
        let mods = KeyboardShortcut.carbonFlags(from: event.modifierFlags)
        // Ignore pure-modifier presses (no virtual keyCode is meaningful)
        if code == 0 && mods != 0 { return nil }
        self.keyCode = code
        self.carbonModifiers = mods
    }

    static func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    static func displayString(fromKeyCode code: UInt32) -> String {
        // Simple mapping for common special keys; default to uppercased character
        switch code {
        case 36: return "⏎" // return
        case 53: return "⎋" // escape
        case 48: return "⇥" // tab
        case 51: return "⌫" // delete
        case 49: return "␣" // space
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            // Try to translate virtual keyCode to a character using TIS
            if let s = KeyboardShortcut.keyCodeToCharacter(Int(code)), !s.isEmpty {
                return s.uppercased()
            }
            return "#\(code)"
        }
    }

    static func displayString(modifiers carbonMods: UInt32) -> String {
        var parts: [String] = []
        if (carbonMods & UInt32(controlKey)) != 0 { parts.append("⌃") }
        if (carbonMods & UInt32(optionKey)) != 0 { parts.append("⌥") }
        if (carbonMods & UInt32(shiftKey)) != 0 { parts.append("⇧") }
        if (carbonMods & UInt32(cmdKey)) != 0 { parts.append("⌘") }
        return parts.joined()
    }

    var displayText: String {
        let mods = Self.displayString(modifiers: carbonModifiers)
        let key = Self.displayString(fromKeyCode: keyCode)
        return mods + key
    }

    private static func keyCodeToCharacter(_ keyCode: Int) -> String? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let ptr = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = unsafeBitCast(ptr, to: CFData.self) as Data
        if data.isEmpty { return nil }
        let keyboardLayout = data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) }
        guard let layoutPtr = keyboardLayout else { return nil }

        var deadKeyState: UInt32 = 0
        let maxStringLength: Int = 4
        var chars: [UniChar] = Array(repeating: 0, count: maxStringLength)
        var actualStringLength: Int = 0

        let result = UCKeyTranslate(layoutPtr,
                                    UInt16(keyCode),
                                    UInt16(kUCKeyActionDisplay),
                                    0,
                                    UInt32(LMGetKbdType()),
                                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                    &deadKeyState,
                                    maxStringLength,
                                    &actualStringLength,
                                    &chars)
        if result == noErr {
            return String(utf16CodeUnits: chars, count: actualStringLength)
        }
        return nil
    }
}

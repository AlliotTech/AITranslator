import Foundation

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
}

enum LanguageUtils {
    static let supported: [Language] = [
        .init(id: "en", name: "English"),
        .init(id: "zh-CN", name: "简体中文"),
        .init(id: "ja", name: "日本語"),
        .init(id: "ko", name: "한국어"),
        .init(id: "fr", name: "Français"),
        .init(id: "de", name: "Deutsch"),
        .init(id: "es", name: "Español")
    ]

    static func displayName(for code: String) -> String {
        supported.first(where: { $0.id == code })?.name ?? code
    }

    static func standardize(code: String) -> String {
        let lower = code.lowercased()
        switch lower {
        case "zh", "zh-cn", "zh_hans", "zh-hans", "zh-sg", "zh-my":
            return "zh-CN"
        case "zh-tw", "zh-hant", "zh_hant", "zh-hk", "zh-mo":
            // Traditional Chinese not currently in supported list; map to zh-CN to stay within supported set
            return "zh-CN"
        default:
            return code
        }
    }

    static func coerceToSupported(code: String, fallback: String = "en") -> String {
        let standardized = standardize(code: code)
        let isSupported = supported.contains(where: { $0.id.lowercased() == standardized.lowercased() })
        return isSupported ? standardized : fallback
    }

    /// Returns whether a language code is right-to-left.
    /// This does not mirror the whole UI; callers should apply layout direction only to text controls.
    static func isRTLLanguage(code: String) -> Bool {
        let lower = code.lowercased()
        // Common RTL language codes
        let rtl: Set<String> = ["ar", "he", "iw", "fa", "ur"]
        if rtl.contains(lower) { return true }
        // Handle regional subtags like ar-SA, fa-IR
        if let prefix = lower.split(separator: "-").first, rtl.contains(String(prefix)) { return true }
        return false
    }
}

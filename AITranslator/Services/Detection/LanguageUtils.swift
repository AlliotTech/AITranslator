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
        supported.first { $0.id == code }?.name ?? code
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
        let isSupported = supported.contains { $0.id.lowercased() == standardized.lowercased() }
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

    /// 计算应用启动时的初始源/目标语言（保证两者不同）
    /// - Parameter defaultTarget: 用户配置的默认目标语言（可能为空）
    /// - Returns: (源语言代码, 目标语言代码)
    static func initialLanguages(defaultTarget: String) -> (source: String, target: String) {
        let configuredTarget = defaultTarget.trimmingCharacters(in: .whitespacesAndNewlines)

        if configuredTarget.isEmpty {
            // 未配置默认目标语言，使用默认组合 en → zh-CN
            return (source: "en", target: "zh-CN")
        }

        // 根据目标语言确定合适的源语言（确保不同）
        if configuredTarget.lowercased().hasPrefix("en") {
            // 目标是英语，源语言使用中文
            return (source: "zh-CN", target: configuredTarget)
        } else if configuredTarget.lowercased().hasPrefix("zh") {
            // 目标是中文，源语言使用英语
            return (source: "en", target: configuredTarget)
        } else {
            // 其他目标语言，默认源语言使用英语
            // 如果与目标相同，则使用中文
            if configuredTarget.lowercased() == "en" {
                return (source: "zh-CN", target: configuredTarget)
            } else {
                return (source: "en", target: configuredTarget)
            }
        }
    }

    /// 计算翻译模式的目标语言
    /// - Parameters:
    ///   - source: 源语言代码
    ///   - defaultTarget: 用户配置的默认目标语言
    /// - Returns: 计算后的目标语言代码
    static func translateTarget(for source: String, defaultTarget: String) -> String {
        let lowerSource = source.lowercased()
        var candidate: String

        // 优先使用默认目标语言（如果已配置）
        let preferred = defaultTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferred.isEmpty {
            // 使用默认目标语言作为候选
            candidate = preferred
        } else {
            // 如果没有配置默认目标语言，使用映射规则：en ↔ zh-CN
            if lowerSource.hasPrefix("en") {
                candidate = "zh-CN"
            } else if lowerSource.hasPrefix("zh") {
                candidate = "en"
            } else {
                // 其他语言默认翻译为英语
                candidate = "en"
            }
        }

        // 确保目标语言与源语言不同
        if candidate.lowercased() == lowerSource {
            // 如果目标与源相同，使用备用映射规则
            candidate = lowerSource.hasPrefix("en") ? "zh-CN" : "en"
        }
        return candidate
    }
}

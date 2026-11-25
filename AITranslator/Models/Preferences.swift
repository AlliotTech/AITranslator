import Foundation

enum DetectionEngine: String, CaseIterable, Codable, Identifiable {
    case local
    case google
    case baidu
    case bing
    var id: String { rawValue }
}

enum ProxyType: String, CaseIterable, Codable, Identifiable {
    case none
    case http
    case socks5
    var id: String { rawValue }
}

enum SendKey: String, CaseIterable, Codable, Identifiable {
    case enter
    case cmdEnter
    var id: String { rawValue }
}

enum TranslationProviderKind: String, CaseIterable, Codable, Identifiable {
    case openAI
    case deepLFree
    case deepLPro
    case deepLCustom

    var id: String { rawValue }

    var isDeepL: Bool { self != .openAI }
}

enum DeepLAPIFamily: String, CaseIterable, Codable, Identifiable {
    case officialV2
    case legacyDeepLX

    var id: String { rawValue }
}

enum DeepLCustomCapability: String, CaseIterable, Codable, Identifiable {
    case translateOnly
    case translateAndWrite

    var id: String { rawValue }
}

/// 用户偏好设置（值类型）
///
/// `Equatable` 与 `encode(to:)` 均由编译器合成；仅 `init(from:)` 手写，
/// 用于容忍旧版本 JSON 中缺失的字段。新增偏好项只需改 3 处：
/// 属性声明、`CodingKeys`、`init` 默认值 + `init(from:)` 的兜底值。
struct Preferences: Codable, Equatable {
    var translationProvider: TranslationProviderKind
    var appLanguage: AppLanguage
    var baseURL: String
    var model: String
    var ocrModel: String
    var apiKey: String
    var customUserAgent: String

    // DeepL-compatible API
    var deepLBaseURL: String
    var deepLAPIKey: String
    var deepLAPIFamily: DeepLAPIFamily
    var deepLCustomCapability: DeepLCustomCapability

    // Language detection
    var detectionEngine: DetectionEngine
    var defaultTargetLanguage: String

    // Network proxy
    var proxyType: ProxyType
    var proxyHost: String
    var proxyPort: Int
    var proxyUsername: String
    var proxyPassword: String
    // Comma-separated hostnames/IPs that bypass proxy
    var noProxyTargets: String

    // Window behavior
    var alwaysOnTop: Bool

    // Layout
    var splitRatio: Double

    // Global shortcuts (optional)
    var shortcutShowWindow: KeyboardShortcut?
    var shortcutToggleMode: KeyboardShortcut?
    var shortcutQuickCopy: KeyboardShortcut?
    var shortcutScreenshotOCR: KeyboardShortcut?

    // Send behavior
    var sendKey: SendKey

    // History settings
    var historyMaxRecords: Int

    enum CodingKeys: CodingKey {
        case translationProvider, appLanguage, baseURL, model, ocrModel, apiKey, customUserAgent
        case deepLBaseURL, deepLAPIKey, deepLAPIFamily, deepLCustomCapability
        case detectionEngine, defaultTargetLanguage, proxyType, proxyHost, proxyPort
        case proxyUsername, proxyPassword, noProxyTargets, alwaysOnTop, splitRatio
        case shortcutShowWindow, shortcutToggleMode, shortcutQuickCopy, shortcutScreenshotOCR, sendKey, historyMaxRecords
    }

    init(
        translationProvider: TranslationProviderKind = .openAI,
        appLanguage: AppLanguage = .system,
        baseURL: String = "https://api.openai.com/v1/chat/completions",
        model: String = "gpt-5-chat",
        ocrModel: String = "gpt-4o-mini",
        apiKey: String = "",
        customUserAgent: String = "",
        deepLBaseURL: String = "",
        deepLAPIKey: String = "",
        deepLAPIFamily: DeepLAPIFamily = .officialV2,
        deepLCustomCapability: DeepLCustomCapability = .translateOnly,
        detectionEngine: DetectionEngine = .local,
        defaultTargetLanguage: String = "en",
        proxyType: ProxyType = .none,
        proxyHost: String = "",
        proxyPort: Int = 0,
        proxyUsername: String = "",
        proxyPassword: String = "",
        noProxyTargets: String = "localhost,127.0.0.1",
        alwaysOnTop: Bool = false,
        splitRatio: Double = 0.5,
        shortcutShowWindow: KeyboardShortcut? = nil,
        shortcutToggleMode: KeyboardShortcut? = nil,
        shortcutQuickCopy: KeyboardShortcut? = nil,
        shortcutScreenshotOCR: KeyboardShortcut? = nil,
        sendKey: SendKey = .cmdEnter,
        historyMaxRecords: Int = 200
    ) {
        self.translationProvider = translationProvider
        self.appLanguage = appLanguage
        self.baseURL = baseURL
        self.model = model
        self.ocrModel = ocrModel
        self.apiKey = apiKey
        self.customUserAgent = customUserAgent
        self.deepLBaseURL = deepLBaseURL
        self.deepLAPIKey = deepLAPIKey
        self.deepLAPIFamily = deepLAPIFamily
        self.deepLCustomCapability = deepLCustomCapability
        self.detectionEngine = detectionEngine
        self.defaultTargetLanguage = LanguageUtils.coerceToSupported(code: defaultTargetLanguage)
        self.proxyType = proxyType
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.proxyUsername = proxyUsername
        self.proxyPassword = proxyPassword
        self.noProxyTargets = noProxyTargets
        self.alwaysOnTop = alwaysOnTop
        self.splitRatio = splitRatio
        self.shortcutShowWindow = shortcutShowWindow
        self.shortcutToggleMode = shortcutToggleMode
        self.shortcutQuickCopy = shortcutQuickCopy
        self.shortcutScreenshotOCR = shortcutScreenshotOCR
        self.sendKey = sendKey
        self.historyMaxRecords = historyMaxRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translationProvider = try container.decodeIfPresent(TranslationProviderKind.self, forKey: .translationProvider) ?? .openAI
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .system
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.openai.com/v1/chat/completions"
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? "gpt-5-chat"
        ocrModel = try container.decodeIfPresent(String.self, forKey: .ocrModel) ?? "gpt-4o-mini"
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        customUserAgent = try container.decodeIfPresent(String.self, forKey: .customUserAgent) ?? ""
        deepLBaseURL = try container.decodeIfPresent(String.self, forKey: .deepLBaseURL) ?? ""
        deepLAPIKey = try container.decodeIfPresent(String.self, forKey: .deepLAPIKey) ?? ""
        deepLAPIFamily = try container.decodeIfPresent(DeepLAPIFamily.self, forKey: .deepLAPIFamily) ?? .officialV2
        deepLCustomCapability = try container.decodeIfPresent(DeepLCustomCapability.self, forKey: .deepLCustomCapability) ?? .translateOnly
        detectionEngine = try container.decodeIfPresent(DetectionEngine.self, forKey: .detectionEngine) ?? .local
        let decodedTarget = try container.decodeIfPresent(String.self, forKey: .defaultTargetLanguage) ?? "en"
        defaultTargetLanguage = LanguageUtils.coerceToSupported(code: decodedTarget)

        // Backward-compatible defaults for removed detection fields are ignored by decoder
        proxyType = try container.decodeIfPresent(ProxyType.self, forKey: .proxyType) ?? .none
        proxyHost = try container.decodeIfPresent(String.self, forKey: .proxyHost) ?? ""
        proxyPort = try container.decodeIfPresent(Int.self, forKey: .proxyPort) ?? 0
        proxyUsername = try container.decodeIfPresent(String.self, forKey: .proxyUsername) ?? ""
        proxyPassword = try container.decodeIfPresent(String.self, forKey: .proxyPassword) ?? ""
        noProxyTargets = try container.decodeIfPresent(String.self, forKey: .noProxyTargets) ?? "localhost,127.0.0.1"
        alwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? false
        splitRatio = try container.decodeIfPresent(Double.self, forKey: .splitRatio) ?? 0.5
        shortcutShowWindow = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .shortcutShowWindow)
        shortcutToggleMode = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .shortcutToggleMode)
        shortcutQuickCopy = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .shortcutQuickCopy)
        shortcutScreenshotOCR = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .shortcutScreenshotOCR)
        sendKey = try container.decodeIfPresent(SendKey.self, forKey: .sendKey) ?? .cmdEnter
        historyMaxRecords = try container.decodeIfPresent(Int.self, forKey: .historyMaxRecords) ?? 200
    }

    // MARK: - Validation Methods

    /// 验证 Base URL 是否有效
    var isBaseURLValid: Bool {
        let text = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: text) != nil && !text.isEmpty
    }

    /// 验证模型名称是否有效
    var isModelValid: Bool {
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 验证 API Key 是否有效
    var isAPIKeyValid: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var resolvedDeepLBaseURL: String {
        switch translationProvider {
        case .deepLFree:
            return "https://api-free.deepl.com"
        case .deepLPro:
            return "https://api.deepl.com"
        case .deepLCustom:
            return deepLBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        case .openAI:
            return ""
        }
    }

    var resolvedDeepLAPIFamily: DeepLAPIFamily {
        translationProvider == .deepLCustom ? deepLAPIFamily : .officialV2
    }

    var deepLSupportsWrite: Bool {
        switch translationProvider {
        case .deepLPro:
            return true
        case .deepLCustom:
            return deepLAPIFamily == .officialV2 && deepLCustomCapability == .translateAndWrite
        case .openAI, .deepLFree:
            return false
        }
    }

    var isDeepLAPIKeyValid: Bool {
        switch translationProvider {
        case .deepLFree, .deepLPro:
            return !deepLAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .deepLCustom, .openAI:
            return true
        }
    }

    var isDeepLBaseURLValid: Bool {
        guard translationProvider == .deepLCustom else { return true }
        return Self.isAllowedDeepLBaseURL(deepLBaseURL)
    }

    static func isAllowedDeepLBaseURL(_ rawValue: String) -> Bool {
        let text = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let components = URLComponents(string: text),
              components.query == nil,
              components.fragment == nil,
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return false
        }

        if scheme == "https" { return true }
        guard scheme == "http" else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    /// 验证代理配置是否有效
    var isProxyValid: Bool {
        if proxyType == .none { return true }
        let hostOk = !proxyHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let portOk = (1...65535).contains(proxyPort)
        return hostOk && portOk
    }

    /// 验证代理主机是否有效（细粒度验证）
    var isProxyHostValid: Bool {
        if proxyType == .none { return true }
        return !proxyHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 验证代理端口是否有效（细粒度验证）
    var isProxyPortValid: Bool {
        if proxyType == .none { return true }
        return (1...65535).contains(proxyPort)
    }

    /// 验证所有必填字段是否有效
    var isValid: Bool {
        let providerValid: Bool
        switch translationProvider {
        case .openAI:
            providerValid = isBaseURLValid && isModelValid && isAPIKeyValid
        case .deepLFree, .deepLPro, .deepLCustom:
            providerValid = isDeepLBaseURLValid && isDeepLAPIKeyValid
        }
        return providerValid && isProxyValid
    }
}

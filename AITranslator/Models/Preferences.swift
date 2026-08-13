import Foundation
import Combine

enum DetectionEngine: String, CaseIterable, Codable, Identifiable {
    case local
    case google
    case baidu
    case bing
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .local: return "本地算法"
        case .google: return "Google"
        case .baidu: return "Baidu"
        case .bing: return "Bing"
        }
    }
}

enum ProxyType: String, CaseIterable, Codable, Identifiable {
    case none
    case http
    case socks5
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "不使用"
        case .http: return "HTTP"
        case .socks5: return "SOCKS5"
        }
    }
}

enum SendKey: String, CaseIterable, Codable, Identifiable {
    case enter
    case cmdEnter
    var id: String { rawValue }
}

enum TranslationProvider: String, CaseIterable, Codable, Identifiable {
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

final class Preferences: ObservableObject, Codable {
    @Published var translationProvider: TranslationProvider
    @Published var appLanguage: AppLanguage
    @Published var baseURL: String
    @Published var model: String
    @Published var apiKey: String

    // DeepL-compatible API
    @Published var deepLBaseURL: String
    @Published var deepLAPIKey: String
    @Published var deepLAPIFamily: DeepLAPIFamily
    @Published var deepLCustomCapability: DeepLCustomCapability

    // Language detection
    @Published var detectionEngine: DetectionEngine
    @Published var defaultTargetLanguage: String

    // Network proxy
    @Published var proxyType: ProxyType
    @Published var proxyHost: String
    @Published var proxyPort: Int
    @Published var proxyUsername: String
    @Published var proxyPassword: String
    // Comma-separated hostnames/IPs that bypass proxy
    @Published var noProxyTargets: String

    // Window behavior
    @Published var alwaysOnTop: Bool

    // Layout
    @Published var splitRatio: Double

    // Global shortcuts (optional)
    @Published var shortcutShowWindow: KeyboardShortcut?
    @Published var shortcutToggleMode: KeyboardShortcut?
    @Published var shortcutQuickCopy: KeyboardShortcut?

    // Send behavior
    @Published var sendKey: SendKey

    // History settings
    @Published var historyMaxRecords: Int

    enum CodingKeys: CodingKey {
        case translationProvider, appLanguage, baseURL, model, apiKey
        case deepLBaseURL, deepLAPIKey, deepLAPIFamily, deepLCustomCapability
        case detectionEngine, defaultTargetLanguage, proxyType, proxyHost, proxyPort
        case proxyUsername, proxyPassword, noProxyTargets, alwaysOnTop, splitRatio
        case shortcutShowWindow, shortcutToggleMode, shortcutQuickCopy, sendKey, historyMaxRecords
    }

    init(
        translationProvider: TranslationProvider = .openAI,
        appLanguage: AppLanguage = .system,
        baseURL: String = "https://api.openai.com/v1/chat/completions",
        model: String = "gpt-5-chat",
        apiKey: String = "",
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
        sendKey: SendKey = .cmdEnter,
        historyMaxRecords: Int = 200
    ) {
        self.translationProvider = translationProvider
        self.appLanguage = appLanguage
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
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
        self.sendKey = sendKey
        self.historyMaxRecords = historyMaxRecords
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translationProvider = try container.decodeIfPresent(TranslationProvider.self, forKey: .translationProvider) ?? .openAI
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .system
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.openai.com/v1/chat/completions"
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? "gpt-5-chat"
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
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
        sendKey = try container.decodeIfPresent(SendKey.self, forKey: .sendKey) ?? .cmdEnter
        historyMaxRecords = try container.decodeIfPresent(Int.self, forKey: .historyMaxRecords) ?? 200
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(translationProvider, forKey: .translationProvider)
        try container.encode(appLanguage, forKey: .appLanguage)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(model, forKey: .model)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encode(deepLBaseURL, forKey: .deepLBaseURL)
        try container.encode(deepLAPIKey, forKey: .deepLAPIKey)
        try container.encode(deepLAPIFamily, forKey: .deepLAPIFamily)
        try container.encode(deepLCustomCapability, forKey: .deepLCustomCapability)
        try container.encode(detectionEngine, forKey: .detectionEngine)
        try container.encode(defaultTargetLanguage, forKey: .defaultTargetLanguage)
        try container.encode(proxyType, forKey: .proxyType)
        try container.encode(proxyHost, forKey: .proxyHost)
        try container.encode(proxyPort, forKey: .proxyPort)
        try container.encode(proxyUsername, forKey: .proxyUsername)
        try container.encode(proxyPassword, forKey: .proxyPassword)
        try container.encode(noProxyTargets, forKey: .noProxyTargets)
        try container.encode(alwaysOnTop, forKey: .alwaysOnTop)
        try container.encode(splitRatio, forKey: .splitRatio)
        try container.encodeIfPresent(shortcutShowWindow, forKey: .shortcutShowWindow)
        try container.encodeIfPresent(shortcutToggleMode, forKey: .shortcutToggleMode)
        try container.encodeIfPresent(shortcutQuickCopy, forKey: .shortcutQuickCopy)
        try container.encode(sendKey, forKey: .sendKey)
        try container.encode(historyMaxRecords, forKey: .historyMaxRecords)
    }

    // MARK: - Helper Methods

    /// 从另一个 Preferences 对象复制所有设置
    /// - Parameter source: 源 Preferences 对象
    func load(from source: Preferences) {
        self.translationProvider = source.translationProvider
        self.appLanguage = source.appLanguage
        self.baseURL = source.baseURL
        self.model = source.model
        self.apiKey = source.apiKey
        self.deepLBaseURL = source.deepLBaseURL
        self.deepLAPIKey = source.deepLAPIKey
        self.deepLAPIFamily = source.deepLAPIFamily
        self.deepLCustomCapability = source.deepLCustomCapability
        self.detectionEngine = source.detectionEngine
        self.defaultTargetLanguage = source.defaultTargetLanguage
        self.proxyType = source.proxyType
        self.proxyHost = source.proxyHost
        self.proxyPort = source.proxyPort
        self.proxyUsername = source.proxyUsername
        self.proxyPassword = source.proxyPassword
        self.noProxyTargets = source.noProxyTargets
        self.alwaysOnTop = source.alwaysOnTop
        self.splitRatio = source.splitRatio
        self.shortcutShowWindow = source.shortcutShowWindow
        self.shortcutToggleMode = source.shortcutToggleMode
        self.shortcutQuickCopy = source.shortcutQuickCopy
        self.sendKey = source.sendKey
        self.historyMaxRecords = source.historyMaxRecords
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

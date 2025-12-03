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

final class Preferences: ObservableObject, Codable {
    @Published var appLanguage: AppLanguage
    @Published var baseURL: String
    @Published var model: String
    @Published var apiKey: String

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
        case appLanguage, baseURL, model, apiKey, detectionEngine, defaultTargetLanguage, proxyType, proxyHost, proxyPort, proxyUsername, proxyPassword, noProxyTargets, alwaysOnTop, splitRatio, shortcutShowWindow, shortcutToggleMode, shortcutQuickCopy, sendKey, historyMaxRecords
    }

    init(
        appLanguage: AppLanguage = .system,
        baseURL: String = "https://api.openai.com/v1/chat/completions",
        model: String = "gpt-5-chat",
        apiKey: String = "",
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
        self.appLanguage = appLanguage
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
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
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .system
        baseURL = try container.decode(String.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        apiKey = try container.decode(String.self, forKey: .apiKey)
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
        try container.encode(appLanguage, forKey: .appLanguage)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(model, forKey: .model)
        try container.encode(apiKey, forKey: .apiKey)
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
        self.appLanguage = source.appLanguage
        self.baseURL = source.baseURL
        self.model = source.model
        self.apiKey = source.apiKey
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
        isBaseURLValid && isModelValid && isAPIKeyValid && isProxyValid
    }
}

import Foundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - Supporting Types

/// 语言覆盖状态管理
/// 统一管理用户手动指定语言的状态，避免使用多个分散的布尔标志
struct LanguageOverrideState {
    /// 用户是否手动指定了源语言
    var source: Bool = false

    /// 用户是否手动指定了目标语言
    var target: Bool = false

    /// 在 Summarize 模式下用户是否手动指定了目标语言
    /// (Summarize 模式有特殊逻辑，目标语言默认跟随源语言)
    var targetInSummarize: Bool = false

    /// 重置所有覆盖状态（例如清空输入时）
    mutating func reset() {
        source = false
        target = false
        targetInSummarize = false
    }

    /// 重置源语言覆盖状态
    mutating func resetSource() {
        source = false
    }

    /// 重置目标语言覆盖状态
    mutating func resetTarget() {
        target = false
        targetInSummarize = false
    }
}

/// 记忆的目标语言
/// 用于模式切换时恢复每个模式之前使用的目标语言
struct RememberedTargetLanguages {
    /// 翻译模式下最后使用的目标语言
    var translate: String?

    /// 总结模式下最后使用的目标语言
    var summarize: String?

    /// 获取指定模式的记忆语言
    func get(for mode: AppMode) -> String? {
        switch mode {
        case .translate:
            return translate
        case .summarize:
            return summarize
        case .polish:
            return nil  // Polish 模式目标语言总是等于源语言
        }
    }

    /// 设置指定模式的记忆语言
    mutating func set(_ language: String, for mode: AppMode) {
        switch mode {
        case .translate:
            translate = language
        case .summarize:
            summarize = language
        case .polish:
            break  // Polish 模式不需要记忆
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var preferences: Preferences
    @Published var session: SessionState

    @Published var toastMessage: String? = nil
    @Published var copyFeedbackToken: Int = 0
    @Published var focusInputToken: Int = 0
    @Published var outputRefreshToken: Int = 0  // 用于窗口显示时刷新输出视图

    // 独立的窗口置顶状态，用于确保视图能正确响应变化
    @Published var isWindowAlwaysOnTop: Bool = false

    // 长文本模式标识（用于UI显示进度提示）
    @Published var isInLongTextMode: Bool = false

    @Published var translationCompletedUnits: Int = 0
    @Published var translationTotalUnits: Int = 0
    @Published var canRetryFromFailure: Bool = false

    // 历史记录管理器
    @Published var historyManager: HistoryManager

    // 历史记录窗口管理器（不需要 @Published，因为窗口状态不需要驱动UI更新）
    let historyWindowManager: HistoryWindowManager

    private let deepL: DeepLServicing
    private let providerResolver: any TranslationProviderResolving
    private var streamTask: Task<Void, Never>?
    private let preferencesStore: PreferencesPersisting
    private var sessionCancellable: AnyCancellable?
    private var preferencesCancellable: AnyCancellable?
    private let hotkeys: HotkeyManaging
    private let pasteDetectDebouncer: Debouncer = Debouncer(intervalMs: 350)

    // 语言检测缓存（避免重复检测相同文本）
    private var lastDetectedText: String? = nil
    private var lastDetectedLang: String? = nil

    // 用户语言覆盖状态（统一管理）
    private var languageOverride = LanguageOverrideState()

    // 流式传输任务代数（用于防止并发任务冲突）
    private var streamGeneration: Int = 0

    // 模式切换时记忆的目标语言
    private var rememberedTargetLanguages = RememberedTargetLanguages()

    // 流式输出批量更新机制
    // 累积多个delta后批量更新UI，大幅降低CPU占用
    private var outputBuffer: String = ""
    private var bufferUpdateTask: Task<Void, Never>?
    private var resumeToken: (any TranslationResumeToken)?

    // 自适应批量更新间隔（毫秒）：根据文本长度动态调整
    // 短文本：更新频繁（流畅）；长文本：更新稀疏甚至暂停（降低CPU）
    private var currentBatchIntervalMs: UInt64 = 16

    // 更新间隔配置
    private let shortTextIntervalMs: UInt64 = 50    // 短文本：20fps
    private let mediumTextIntervalMs: UInt64 = 160  // 中等文本：~6fps
    private let longTextIntervalMs: UInt64 = 300    // 长文本：~3fps（降低卡顿但保持实时感）

    // 文本长度阈值
    private let shortTextThreshold = 500       // 500字符以下为短文本
    private let mediumTextThreshold = 3000     // 3000字符以下为中等文本

    // 超长文本保护模式（仅极端场景触发）
    private var isLongTextMode: Bool = false
    private let veryLongTextThreshold = 20000  // 超过此值进入"仅显示进度"模式

    var isStreaming: Bool { session.isStreaming }

    private var currentCapabilities: TranslationCapabilities {
        providerResolver.provider(for: preferences).capabilities
    }

    var isPolishAvailable: Bool { currentCapabilities.supportsPolish }

    var isSummarizeAvailable: Bool { currentCapabilities.supportsSummarize }

    // Send button should be disabled when input is empty or whitespace-only
    var isSendDisabled: Bool {
        session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isModeAvailable(session.mode)
    }

    // 计算属性：避免视图中重复调用trimmingCharacters
    // 这些属性用于控制UI元素的可见性和可用性
    var isOutputEmpty: Bool {
        session.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isInputEmpty: Bool {
        session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isBothEmpty: Bool {
        isInputEmpty && isOutputEmpty
    }

    // MARK: - Helper Methods

    /// 判断是否应该自动触发翻译/润色/总结
    /// - Parameter changeType: 语言变更类型
    /// - Returns: 是否应该自动触发
    private func shouldAutoSend(after changeType: LanguageChangeType) -> Bool {
        // 检查是否有输入内容
        guard !session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        switch (session.mode, changeType) {
        case (.translate, .source), (.translate, .target):
            // 翻译模式：改变源语言或目标语言都自动触发
            return true
        case (.polish, .source):
            // 润色模式：改变源语言自动触发（目标语言会自动跟随源语言）
            return true
        case (.polish, .target):
            // 润色模式：目标语言由源语言决定，不需要单独触发
            return false
        case (.summarize, .source), (.summarize, .target):
            // 总结模式：改变源语言或目标语言都自动触发
            return true
        }
    }

    /// 语言变更类型
    private enum LanguageChangeType {
        case source  // 源语言变更
        case target  // 目标语言变更
    }

    func isModeAvailable(_ mode: AppMode) -> Bool {
        currentCapabilities.supports(mode)
    }

    private func enforceAvailableMode(showNotice: Bool) {
        guard !isModeAvailable(session.mode) else { return }
        setMode(.translate, autoSend: false)
        if showNotice {
            showToast(L10n.tr("toast.mode.switchedToTranslate", lang: preferences.appLanguage))
        }
    }

    private func resetTranslationProgress() {
        translationCompletedUnits = 0
        translationTotalUnits = 0
        canRetryFromFailure = false
        resumeToken = nil
    }

    private func deepLConfiguration(from preferences: Preferences) -> DeepLServiceConfiguration {
        DeepLServiceConfiguration(
            baseURL: preferences.resolvedDeepLBaseURL,
            apiKey: preferences.deepLAPIKey,
            apiFamily: preferences.resolvedDeepLAPIFamily,
            supportsWrite: preferences.deepLSupportsWrite
        )
    }

    private func currentRequest(proxy: HTTPClient.ProxySettings?) -> TranslationRequest {
        TranslationRequest(
            mode: session.mode,
            input: session.input,
            sourceLanguage: session.sourceLang,
            targetLanguage: session.targetLang,
            proxy: proxy
        )
    }

    /// 构建代理配置（统一方法，避免重复代码）
    private func buildProxySettings() -> HTTPClient.ProxySettings? {
        buildProxySettings(from: preferences)
    }

    private func buildProxySettings(from preferences: Preferences) -> HTTPClient.ProxySettings? {
        let type = preferences.proxyType
        let host = preferences.proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = preferences.proxyPort

        if type == .none || host.isEmpty || port <= 0 { return nil }

        let username = preferences.proxyUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = preferences.proxyPassword
        let bypass = preferences.noProxyTargets
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return HTTPClient.ProxySettings(
            type: type,
            host: host,
            port: port,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            noProxyHosts: bypass
        )
    }

    /// 检测源语言（统一方法，包含缓存逻辑）
    /// - Parameters:
    ///   - text: 待检测的文本
    ///   - proxy: 代理配置
    /// - Returns: 标准化的语言代码
    private func detectSourceLanguage(for text: String, proxy: HTTPClient.ProxySettings?) async -> String {
        let engine = self.preferences.detectionEngine
        let limited = LanguageDetector.limitedText(text, for: engine)

        // 检查缓存
        if let cachedText = self.lastDetectedText,
           let cachedLang = self.lastDetectedLang,
           cachedText == limited {
            return LanguageUtils.standardize(code: cachedLang)
        }

        // 执行检测
        let result = await LanguageDetector.detect(text: limited, engine: engine, proxy: proxy)
        let standardized = LanguageUtils.standardize(code: result.languageCode)

        // 更新缓存
        self.lastDetectedText = limited
        self.lastDetectedLang = standardized

        return standardized
    }

    // MARK: - Target language computation for Translate mode

    /// 计算翻译模式的目标语言
    /// - Parameters:
    ///   - source: 源语言代码
    ///   - defaultTarget: 用户配置的默认目标语言
    /// - Returns: 计算后的目标语言代码
    private func computeTranslateTarget(
        source: String,
        defaultTarget: String
    ) -> String {
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

    init(
        openai: OpenAIStreamingClient,
        deepL: DeepLServicing,
        preferencesStore: PreferencesPersisting,
        hotkeys: HotkeyManaging
    ) {
        self.deepL = deepL
        self.providerResolver = DefaultTranslationProviderResolver(openAI: openai, deepL: deepL)
        self.preferencesStore = preferencesStore
        self.hotkeys = hotkeys

        // 先加载 preferences
        let loadedPreferences: Preferences
        if let loaded = preferencesStore.load() {
            loadedPreferences = loaded
        } else {
            loadedPreferences = Preferences()
        }

        // 计算初始语言设置
        let configuredTarget = loadedPreferences.defaultTargetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)

        // 确定目标语言和源语言，确保两者不同
        let initialSource: String
        let initialTarget: String

        if configuredTarget.isEmpty {
            // 未配置默认目标语言，使用默认组合 en → zh-CN
            initialSource = "en"
            initialTarget = "zh-CN"
        } else {
            // 使用配置的目标语言
            initialTarget = configuredTarget

            // 根据目标语言确定合适的源语言（确保不同）
            if configuredTarget.lowercased().hasPrefix("en") {
                // 目标是英语，源语言使用中文
                initialSource = "zh-CN"
            } else if configuredTarget.lowercased().hasPrefix("zh") {
                // 目标是中文，源语言使用英语
                initialSource = "en"
            } else {
                // 其他目标语言，默认源语言使用英语
                // 如果与目标相同，则使用中文
                if configuredTarget.lowercased() == "en" {
                    initialSource = "zh-CN"
                } else {
                    initialSource = "en"
                }
            }
        }

        // 初始化所有存储属性
        self.preferences = loadedPreferences
        self.session = SessionState(sourceLang: initialSource, targetLang: initialTarget)
        self.isWindowAlwaysOnTop = loadedPreferences.alwaysOnTop

        // 初始化历史记录管理器
        self.historyManager = HistoryManager()

        // 初始化历史记录窗口管理器
        self.historyWindowManager = HistoryWindowManager()

        // 所有存储属性初始化完成后，同步历史记录配置
        self.historyManager.maxRecords = loadedPreferences.historyMaxRecords

        if !providerResolver.provider(for: loadedPreferences).capabilities.supports(session.mode) {
            session.mode = .translate
        }

        bindSession()
        bindPreferences()
        configureHotkeyCallbacks()
        applyHotkeysFromPreferences()
    }

    convenience init() {
        self.init(
            openai: OpenAIClient(),
            deepL: DeepLClient(),
            preferencesStore: PreferencesStore(),
            hotkeys: HotkeyManager.shared
        )
    }

    private func bindSession() {
        sessionCancellable = session.objectWillChange.sink { [weak self] _ in
            // Forward nested session changes to the view model on next runloop turn
            // to avoid publishing during an active view update cycle.
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    /// 绑定 preferences 的变化，确保嵌套 ObservableObject 的变化能传播到视图
    private func bindPreferences() {
        preferencesCancellable = preferences.objectWillChange.sink { [weak self] _ in
            // 转发 preferences 内部属性的变化到 AppViewModel
            // 这样 WindowLevelAdapter 等依赖 preferences 属性的视图才能正确更新
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    func savePreferences() {
        // 检查代理配置是否变更，如果变更则清理缓存的URLSession
        let proxyChanged: Bool = {
            guard let old = preferencesStore.load() else { return true }
            return old.proxyType != preferences.proxyType ||
                   old.proxyHost != preferences.proxyHost ||
                   old.proxyPort != preferences.proxyPort ||
                   old.proxyUsername != preferences.proxyUsername ||
                   old.proxyPassword != preferences.proxyPassword ||
                   old.noProxyTargets != preferences.noProxyTargets
        }()

        // 同步独立的窗口置顶状态
        isWindowAlwaysOnTop = preferences.alwaysOnTop

        // 同步历史记录配置到 HistoryManager
        historyManager.maxRecords = preferences.historyMaxRecords

        preferencesStore.save(preferences)
        applyHotkeysFromPreferences()
        resetTranslationProgress()
        enforceAvailableMode(showNotice: true)

        // 代理配置变更时，清理所有缓存的URLSession以避免使用旧配置
        if proxyChanged {
            HTTPClient.invalidateAllSessions()
        }
    }

    func showToast(_ message: String, duration seconds: TimeInterval = 2.0) {
        toastMessage = message
        Accessibility.announce(message)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                // Only clear if unchanged to avoid racing newer messages
                if self?.toastMessage == message {
                    self?.toastMessage = nil
                }
            }
        }
    }

    func onInputChanged(_ newValue: String) {
        guard session.input != newValue else { return }
        resetTranslationProgress()
        session.input = newValue
        // Do not detect on input; detection will run on send() when needed
        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 清空输入时重置所有覆盖状态和检测缓存
            languageOverride.reset()
            lastDetectedText = nil
            lastDetectedLang = nil
        }
    }

    // Schedule a short-delayed language detection after paste
    func scheduleDetectionAfterPaste() {
        // Summarize 模式不需要检测源语言（AI可以自动识别任意语言）
        guard session.mode != .summarize else { return }

        // 粘贴后允许重新检测语言
        languageOverride.resetSource()
        pasteDetectDebouncer.schedule { [weak self] in
            Task {
                await self?.detectLanguageForCurrentInput()
            }
        }
    }

    func setSourceLang(_ code: String) {
        let coerced = LanguageUtils.coerceToSupported(code: code, fallback: "en")
        if session.sourceLang != coerced { session.sourceLang = coerced }
        resetTranslationProgress()

        // 标记用户已手动指定源语言
        languageOverride.source = true

        // 根据模式调整目标语言
        if session.mode == .polish {
            // Polish 模式：目标语言总是等于源语言
            if session.targetLang != session.sourceLang {
                session.targetLang = session.sourceLang
            }
        } else if session.mode == .summarize {
            // Summarize 模式：目标语言跟随源语言（除非用户手动指定过）
            if !languageOverride.targetInSummarize, session.targetLang != session.sourceLang {
                session.targetLang = session.sourceLang
            }
        }

        // 统一的自动触发逻辑
        if shouldAutoSend(after: .source) {
            send()
        }
    }

    func setTargetLang(_ code: String) {
        session.targetLang = LanguageUtils.coerceToSupported(code: code, fallback: "en")
        resetTranslationProgress()

        // 标记用户已手动指定目标语言
        languageOverride.target = true
        if session.mode == .summarize {
            languageOverride.targetInSummarize = true
        }

        // 记录每个模式的最后目标语言，用于模式切换时恢复
        // Polish 模式不需要记录（目标语言总是等于源语言）
        if session.mode != .polish {
            rememberedTargetLanguages.set(session.targetLang, for: session.mode)
        }

        // 统一的自动触发逻辑
        if shouldAutoSend(after: .target) {
            send()
        }
    }

    func swapLanguages() {
        let tmp = session.sourceLang
        session.sourceLang = session.targetLang
        session.targetLang = tmp
        resetTranslationProgress()

        // 交换语言是明确的用户操作，标记为手动指定
        languageOverride.source = true
        languageOverride.target = true
        if session.mode == .summarize {
            languageOverride.targetInSummarize = true
        }
    }

    func send() {
        guard !session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard isModeAvailable(session.mode) else {
            enforceAvailableMode(showNotice: true)
            return
        }

        session.error = nil
        session.output = ""
        session.isStreaming = true
        Accessibility.announce(L10n.tr("streaming.a11y", lang: preferences.appLanguage))

        streamTask?.cancel()
        // 清理之前的批量更新任务
        bufferUpdateTask?.cancel()
        bufferUpdateTask = nil
        outputBuffer = ""

        // 重置长文本模式
        isLongTextMode = false
        isInLongTextMode = false
        resetTranslationProgress()

        streamGeneration &+= 1
        let generation = streamGeneration
        streamTask = Task { [weak self] in
            guard let self else { return }

            // 使用统一的代理配置构建方法
            let proxy = self.buildProxySettings()

            // 检测语言（仅在翻译模式且用户未手动指定时）
            var effectiveSource = self.session.sourceLang
            var effectiveTarget = self.session.targetLang

            if self.session.mode == .translate {
                // 检测源语言（如果用户未手动指定）
                if !self.languageOverride.source {
                    effectiveSource = await self.detectSourceLanguage(
                        for: self.session.input,
                        proxy: proxy
                    )
                }

                // 计算目标语言
                let currentTargetEmpty = self.session.targetLang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                effectiveTarget = computeTranslateTarget(
                    source: effectiveSource,
                    defaultTarget: self.preferences.defaultTargetLanguage
                )

                // 应用检测结果到 session
                await MainActor.run {
                    guard self.streamGeneration == generation else { return }

                    // 更新源语言（如果未被用户覆盖）
                    if !self.languageOverride.source {
                        let coercedSource = LanguageUtils.coerceToSupported(code: effectiveSource, fallback: "en")
                        if self.session.sourceLang != coercedSource {
                            self.session.sourceLang = coercedSource
                        }
                    }

                    // 更新目标语言（如果未被用户覆盖，或目标为空）
                    let shouldAutoAdjust = !self.languageOverride.target || currentTargetEmpty
                    if shouldAutoAdjust {
                        let coercedTarget = LanguageUtils.coerceToSupported(code: effectiveTarget, fallback: "en")
                        if self.session.targetLang != coercedTarget {
                            self.session.targetLang = coercedTarget
                        }
                    }
                }
            }

            let provider = self.providerResolver.provider(for: self.preferences)
            let completed = await self.consume(
                provider.events(for: self.currentRequest(proxy: proxy)),
                delivery: provider.delivery,
                generation: generation
            )

            self.finishRequest(
                completed: completed,
                identity: provider.identity,
                generation: generation
            )
        }
    }

    /// 从上次失败处续传（仅当提供方支持且句柄与当前请求兼容）
    func retryFromFailure() {
        guard let token = resumeToken,
              canRetryFromFailure,
              !session.isStreaming else {
            resetTranslationProgress()
            return
        }

        let provider = providerResolver.provider(for: preferences)
        let request = currentRequest(proxy: buildProxySettings())
        guard let events = provider.resumeEvents(from: token, request: request) else {
            resetTranslationProgress()
            return
        }

        session.error = nil
        session.isStreaming = true
        canRetryFromFailure = false
        outputBuffer = ""
        Accessibility.announce(L10n.tr("streaming.a11y", lang: preferences.appLanguage))

        streamGeneration &+= 1
        let generation = streamGeneration
        streamTask = Task { [weak self] in
            guard let self else { return }
            let completed = await self.consume(
                events,
                delivery: provider.delivery,
                generation: generation
            )
            self.finishRequest(
                completed: completed,
                identity: provider.identity,
                generation: generation
            )
        }
    }

    func stopStreaming() {
        // 增加 generation 使循环中的 guard 检查失效，阻止后续 delta 更新 UI
        streamGeneration &+= 1
        streamTask?.cancel()

        // 停止批量更新任务并刷新最后的缓冲内容（包括长文本模式下的累积内容）
        bufferUpdateTask?.cancel()
        bufferUpdateTask = nil
        flushOutputBuffer()

        session.isStreaming = false
        resetTranslationProgress()
    }

    /// 消费提供方事件流，是所有提供方共用的唯一执行路径
    private func consume(
        _ events: AsyncThrowingStream<TranslationEvent, Error>,
        delivery: TranslationDelivery,
        generation: Int
    ) async -> Bool {
        if delivery == .incrementalStream {
            await startBatchUpdateTask(generation: generation)
        }

        do {
            for try await event in events {
                guard streamGeneration == generation else { return false }
                switch event {
                case .delta(let text):
                    outputBuffer.append(text)
                    // 分块提供方每块到达即刷新，不参与流式批量节流
                    if delivery == .chunkedBatches {
                        flushOutputBuffer()
                    }

                case .reset(let text):
                    outputBuffer = ""
                    session.output = text

                case let .progress(completed, total):
                    translationCompletedUnits = completed
                    translationTotalUnits = total
                }
            }
            guard streamGeneration == generation else { return false }
            flushOutputBuffer()
            resumeToken = nil
            canRetryFromFailure = false
            return true
        } catch is CancellationError {
            return false
        } catch let error as URLError where error.code == .cancelled {
            return false
        } catch let failure as TranslationFailure {
            guard streamGeneration == generation else { return false }
            flushOutputBuffer()
            session.error = failure.message
            resumeToken = failure.resumeToken
            canRetryFromFailure = failure.resumeToken != nil
            Accessibility.announce(L10n.tr("failed", lang: preferences.appLanguage))
            return false
        } catch {
            guard streamGeneration == generation else { return false }
            flushOutputBuffer()
            session.error = error.localizedDescription
            Accessibility.announce(L10n.tr("failed", lang: preferences.appLanguage))
            return false
        }
    }

    private func finishRequest(
        completed: Bool,
        identity: TranslationProviderIdentity,
        generation: Int
    ) {
        bufferUpdateTask?.cancel()
        bufferUpdateTask = nil
        guard streamGeneration == generation else { return }

        flushOutputBuffer()
        session.isStreaming = false
        guard completed, session.error == nil, !session.output.isEmpty else { return }

        Accessibility.announce(L10n.tr("completed.a11y", lang: preferences.appLanguage))
        historyManager.addRecord(
            mode: session.mode,
            sourceLang: session.sourceLang,
            targetLang: session.targetLang,
            input: session.input,
            output: session.output,
            provider: identity.historyProvider,
            service: identity.service
        )
    }

    // MARK: - 批量更新优化

    /// 启动批量更新任务
    /// 定期将缓冲区的内容刷新到UI，避免每个token都触发UI更新
    /// 自适应调整更新频率：文本越长，更新越稀疏
    private func startBatchUpdateTask(generation: Int) async {
        await MainActor.run {
            // 如果已有任务在运行，先取消
            self.bufferUpdateTask?.cancel()

            // 初始化为短文本间隔
            self.currentBatchIntervalMs = self.shortTextIntervalMs

            self.bufferUpdateTask = Task { [weak self] in
                while !Task.isCancelled {
                    // 在每次循环开始时检查self
                    guard let strongSelf = self else { break }

                    // 等待指定间隔（自适应）
                    try? await Task.sleep(nanoseconds: strongSelf.currentBatchIntervalMs * 1_000_000)

                    // 检查任务是否被取消
                    guard !Task.isCancelled else { break }

                    // 在主线程执行UI更新
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        guard self.streamGeneration == generation else { return }

                        // 根据当前文本长度自适应调整更新间隔（在刷新前检查）
                        self.adjustBatchInterval()

                        // 长文本模式：停止UI更新，只累积数据
                        // 这样可以完全避免Text视图的频繁重新渲染
                        if !self.isLongTextMode {
                            // 正常模式：刷新缓冲区到UI
                            self.flushOutputBuffer()
                        }
                        // 长文本模式下，数据仍在outputBuffer中累积，不会丢失
                    }
                }
            }
        }
    }

    /// 根据当前输出文本长度自适应调整批量更新间隔
    /// 文本越长，更新频率越低，以降低CPU占用
    private func adjustBatchInterval() {
        let currentLength = session.output.count
        let bufferLength = outputBuffer.count
        let totalLength = currentLength + bufferLength

        let wasLongTextMode = isLongTextMode

        if totalLength < shortTextThreshold {
            // 短文本：20fps，保证流畅
            currentBatchIntervalMs = shortTextIntervalMs
            isLongTextMode = false
        } else if totalLength < mediumTextThreshold {
            // 中等文本：5fps，平衡性能和流畅度
            currentBatchIntervalMs = mediumTextIntervalMs
            isLongTextMode = false
        } else if totalLength < veryLongTextThreshold {
            // 长文本：1fps，大幅降低CPU占用
            currentBatchIntervalMs = longTextIntervalMs
            isLongTextMode = false
        } else {
            // 超长文本：进入"仅显示进度"模式
            // 完全停止UI更新，只在完成时显示
            isLongTextMode = true
        }

        // 更新UI状态（用于显示进度提示）
        if wasLongTextMode != isLongTextMode {
            isInLongTextMode = isLongTextMode
        }
    }

    /// 将缓冲区内容刷新到output
    /// 这是实际触发UI更新的地方
    /// 优化：使用预分配容量减少内存重分配
    private func flushOutputBuffer() {
        guard !outputBuffer.isEmpty else { return }

        // 对于长文本，使用更高效的字符串拼接方式
        if session.output.isEmpty {
            session.output = outputBuffer
        } else {
            // 预估最终容量，减少内存重分配
            session.output.reserveCapacity(session.output.count + outputBuffer.count)
            session.output.append(outputBuffer)
        }

        outputBuffer = ""
    }

    func copyOutputToClipboard() {
        let text = session.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copyFeedbackToken &+= 1
        showToast(L10n.tr("toast.copied", lang: preferences.appLanguage))
    }

    func toggleShowHideWindow() {
        // 获取主窗口（排除辅助窗口如设置窗口、历史记录窗口）
        let mainWindow = WindowLevelManager.shared.getMainWindow()

        // 检查主窗口是否可见
        let isMainWindowVisible = mainWindow?.isVisible == true && mainWindow?.isMiniaturized == false

        if NSApp.isHidden == false && NSApp.isActive && isMainWindowVisible {
            // 隐藏主窗口
            // 注意：只隐藏主窗口，不影响辅助窗口（设置、历史记录等）
            mainWindow?.orderOut(nil)
            return
        }

        // 显示主窗口
        if let window = mainWindow {
            if window.isMiniaturized {
                // 如果主窗口被最小化到 Dock，先恢复
                if NSApp.isHidden { NSApp.unhide(nil) }
                window.deminiaturize(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // 显示主窗口
                if NSApp.isHidden { NSApp.unhide(nil) }
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            // 主窗口引用不存在，尝试查找第一个非辅助窗口
            // 这是一个备用方案，正常情况下不应该执行到这里
            if let firstWindow = NSApp.windows.first(where: { window in
                window.canBecomeKey && !WindowLevelManager.shared.isAuxiliaryWindow(window)
            }) {
                if NSApp.isHidden { NSApp.unhide(nil) }
                firstWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // 最后的备用方案：只激活应用
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        // Delay focus trigger to ensure window is fully activated and ready
        // This prevents the focus token from being processed before the window becomes key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.focusInputToken &+= 1
            // 强制刷新输出视图，修复 .textSelection(.enabled) 在窗口隐藏后显示时不渲染的问题
            self?.outputRefreshToken &+= 1
        }
    }

    func toggleMode() {
        let modes = AppMode.allCases
        let currentIndex = modes.firstIndex(of: session.mode) ?? 0
        let nextMode = (1...modes.count)
            .lazy
            .map { modes[(currentIndex + $0) % modes.count] }
            .first(where: isModeAvailable) ?? .translate
        setMode(nextMode)
    }

    func toggleAlwaysOnTop() {
        preferences.alwaysOnTop.toggle()
        isWindowAlwaysOnTop = preferences.alwaysOnTop  // 同步更新独立状态
        savePreferences()
        showToast(preferences.alwaysOnTop ? L10n.tr("toast.pinned", lang: preferences.appLanguage) : L10n.tr("toast.unpinned", lang: preferences.appLanguage))
    }

    func showHistoryWindow() {
        historyWindowManager.show(historyManager: historyManager, preferences: preferences)
    }

    /// 重置语言覆盖状态和检测缓存（例如清空输入后）
    func resetOverridesAfterClear() {
        languageOverride.reset()
        lastDetectedText = nil
        lastDetectedLang = nil
        resetTranslationProgress()
    }

    func restoreAfterClear(input: String, output: String) {
        onInputChanged(input)
        session.output = output
        resetTranslationProgress()
    }

    func restoreLanguages(source: String, target: String) {
        session.sourceLang = LanguageUtils.coerceToSupported(code: source, fallback: "en")
        session.targetLang = LanguageUtils.coerceToSupported(code: target, fallback: "en")
        languageOverride.source = true
        languageOverride.target = true
        if session.mode == .summarize {
            languageOverride.targetInSummarize = true
        }
        resetTranslationProgress()
    }

    func testDeepLConnection(preferences: Preferences) async throws -> DeepLConnectionTestResult {
        guard preferences.translationProvider.isDeepL else {
            throw DeepLServiceError(statusCode: nil, message: "DeepL is not selected.")
        }
        return try await deepL.testConnection(
            configuration: deepLConfiguration(from: preferences),
            proxy: buildProxySettings(from: preferences)
        )
    }

    // Export current preferences to a JSON file via NSSavePanel
    func exportPreferencesToJSON() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "ai-translator-preferences.json"
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.json]
        } else {
            panel.allowedFileTypes = ["json"]
        }
        panel.isExtensionHidden = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(preferences)
            if var jsonString = String(data: data, encoding: .utf8) {
                jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
                if let cleanedData = jsonString.data(using: .utf8) {
                    try cleanedData.write(to: url, options: .atomic)
                } else {
                    try data.write(to: url, options: .atomic)
                }
            } else {
                try data.write(to: url, options: .atomic)
            }
            showToast(L10n.tr("toast.export.success", lang: preferences.appLanguage))
        } catch {
            showToast(L10n.tr("toast.export.failure.prefix", lang: preferences.appLanguage) + error.localizedDescription)
        }
    }

    // Import preferences from a JSON file via NSOpenPanel
    // Returns preferences without applying; caller decides when to save/apply
    func importPreferencesFromJSON() -> Preferences? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.json]
        } else {
            panel.allowedFileTypes = ["json"]
        }

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(Preferences.self, from: data)
            // Do not apply automatically; caller should set draft and save explicitly
            return decoded
        } catch {
            showToast(L10n.tr("toast.import.failure.prefix", lang: preferences.appLanguage) + error.localizedDescription)
            return nil
        }
    }
}

extension AppViewModel {
    func setMode(_ newMode: AppMode, autoSend: Bool = true) {
        let oldMode = session.mode
        guard oldMode != newMode else { return }

        resetTranslationProgress()
        guard isModeAvailable(newMode) else {
            showToast(L10n.tr("toast.mode.switchedToTranslate", lang: preferences.appLanguage))
            return
        }

        session.mode = newMode
        applyModeTransition(from: oldMode, to: newMode)

        if autoSend,
           !session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            send()
        }
    }

    private func applyModeTransition(from oldMode: AppMode, to newMode: AppMode) {
        guard oldMode != newMode else { return }

        // 保存旧模式的目标语言，以便后续恢复
        rememberedTargetLanguages.set(session.targetLang, for: oldMode)

        // 根据新模式应用语言规则
        switch newMode {
        case .polish:
            // Polish 模式：目标语言总是等于源语言
            if session.targetLang != session.sourceLang {
                session.targetLang = session.sourceLang
            }

        case .translate:
            // 尝试恢复翻译模式之前的目标语言
            if let remembered = rememberedTargetLanguages.get(for: .translate),
               !remembered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if session.targetLang != remembered {
                    session.targetLang = remembered
                }
                // 将恢复的语言视为用户偏好，避免立即自动调整
                languageOverride.target = true
            }

        case .summarize:
            // 尝试恢复总结模式之前的目标语言
            if let remembered = rememberedTargetLanguages.get(for: .summarize),
               !remembered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if session.targetLang != remembered {
                    session.targetLang = remembered
                }
                // 防止 Summarize 模式的自动同步覆盖已恢复的目标语言
                languageOverride.targetInSummarize = true
            }
        }
    }
}

// MARK: - Paste-triggered detection
private extension AppViewModel {
    func detectLanguageForCurrentInput() async {
        let trimmed = session.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 使用统一的代理配置构建方法
        let proxy = self.buildProxySettings()

        // 检测源语言（如果用户未手动指定）
        var effectiveSource = self.session.sourceLang
        if !languageOverride.source {
            effectiveSource = await self.detectSourceLanguage(for: trimmed, proxy: proxy)
        }

        // 根据不同模式处理语言设置
        if session.mode == .translate {
            // 翻译模式：计算目标语言
            let currentTargetEmpty = self.session.targetLang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let effectiveTarget = computeTranslateTarget(
                source: effectiveSource,
                defaultTarget: self.preferences.defaultTargetLanguage
            )

            await MainActor.run {
                // 更新源语言（如果未被用户覆盖）
                if !self.languageOverride.source {
                    if self.session.sourceLang != effectiveSource {
                        self.session.sourceLang = effectiveSource
                    }
                }

                // 更新目标语言（如果未被用户覆盖，或目标为空）
                let shouldAutoAdjust = !self.languageOverride.target || currentTargetEmpty
                if shouldAutoAdjust {
                    let coercedTarget = LanguageUtils.coerceToSupported(code: effectiveTarget, fallback: "en")
                    if self.session.targetLang != coercedTarget {
                        self.session.targetLang = coercedTarget
                    }
                }
            }
        } else {
            // Polish/Summarize 模式：目标语言跟随源语言
            await MainActor.run {
                let coercedSource = LanguageUtils.coerceToSupported(code: effectiveSource, fallback: "en")
                if self.session.sourceLang != coercedSource {
                    self.session.sourceLang = coercedSource
                }

                // Polish 模式：目标语言总是等于源语言
                if self.session.mode == .polish {
                    if self.session.targetLang != coercedSource {
                        self.session.targetLang = coercedSource
                    }
                } else { // Summarize 模式：目标语言跟随源语言（除非用户手动指定）
                    if !self.languageOverride.targetInSummarize,
                       self.session.targetLang != coercedSource {
                        self.session.targetLang = coercedSource
                    }
                }
            }
        }
    }
}

private extension AppViewModel {
    func configureHotkeyCallbacks() {
        hotkeys.onShowWindow = { [weak self] in self?.toggleShowHideWindow() }
        hotkeys.onToggleMode = { [weak self] in self?.toggleMode() }
        hotkeys.onQuickCopy = { [weak self] in self?.copyOutputToClipboard() }
    }

    func applyHotkeysFromPreferences() {
        hotkeys.apply(
            show: preferences.shortcutShowWindow,
            toggle: preferences.shortcutToggleMode,
            copy: preferences.shortcutQuickCopy
        )
    }
}

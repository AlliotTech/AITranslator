import Foundation

/// 一次翻译/润色/总结请求的输入
struct TranslationRequest: Equatable, Sendable {
    let mode: AppMode
    let input: String
    let sourceLanguage: String
    let targetLanguage: String
    let proxy: HTTPClient.ProxySettings?
}

/// 提供方支持的模式能力
struct TranslationCapabilities: Equatable, Sendable {
    let supportsPolish: Bool
    let supportsSummarize: Bool

    func supports(_ mode: AppMode) -> Bool {
        switch mode {
        case .translate:
            return true
        case .polish:
            return supportsPolish
        case .summarize:
            return supportsSummarize
        }
    }
}

/// 输出投递方式：决定 ViewModel 的 UI 刷新节奏
enum TranslationDelivery: Equatable, Sendable {
    /// 逐 token 流式输出，需要批量缓冲刷新
    case incrementalStream
    /// 按块整段返回，每块到达即刷新
    case chunkedBatches
}

/// 历史记录所需的提供方标识
struct TranslationProviderIdentity: Equatable, Sendable {
    let historyProvider: HistoryProvider
    let service: String
}

/// 翻译提供方统一接口
///
/// 提供方负责一切与自身协议相关的细节（提示词、分块、续传、错误文案），
/// 对外只暴露 `TranslationEvent` 序列。
@MainActor
protocol TranslationProvider {
    var identity: TranslationProviderIdentity { get }
    var capabilities: TranslationCapabilities { get }
    var delivery: TranslationDelivery { get }

    /// 执行一次完整请求
    func events(for request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, Error>

    /// 从续传句柄继续；句柄与当前请求不兼容时返回 nil
    func resumeEvents(
        from token: any TranslationResumeToken,
        request: TranslationRequest
    ) -> AsyncThrowingStream<TranslationEvent, Error>?
}

extension TranslationProvider {
    func resumeEvents(
        from token: any TranslationResumeToken,
        request: TranslationRequest
    ) -> AsyncThrowingStream<TranslationEvent, Error>? {
        nil
    }
}

/// 根据偏好设置解析出当前提供方
@MainActor
protocol TranslationProviderResolving {
    func provider(for preferences: Preferences) -> any TranslationProvider
}

struct DefaultTranslationProviderResolver: TranslationProviderResolving {
    let openAI: OpenAIStreamingClient
    let deepL: DeepLServicing

    func provider(for preferences: Preferences) -> any TranslationProvider {
        switch preferences.translationProvider {
        case .openAI:
            return OpenAITranslationProvider(client: openAI, preferences: preferences)
        case .deepLFree, .deepLPro, .deepLCustom:
            return DeepLTranslationProvider(client: deepL, preferences: preferences)
        }
    }
}

import Foundation

protocol OpenAIStreamingClient {
    func stream(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [OpenAIClient.RequestBody.Message],
        parameters: AITaskParameters,
        proxy: HTTPClient.ProxySettings?,
        userAgent: String?
    ) -> AsyncThrowingStream<String, Error>
}

protocol DeepLServicing {
    func prepareChunks(text: String, context: DeepLRequestContext) throws -> [DeepLTextChunk]

    func execute(
        text: String,
        context: DeepLRequestContext,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> String

    func testConnection(
        configuration: DeepLServiceConfiguration,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> DeepLConnectionTestResult
}

protocol PreferencesPersisting {
    func load() -> Preferences?
    func save(_ preferences: Preferences)
}

protocol HotkeyManaging: AnyObject {
    var onShowWindow: (() -> Void)? { get set }
    var onToggleMode: (() -> Void)? { get set }
    var onQuickCopy: (() -> Void)? { get set }
    var onScreenshotOCR: (() -> Void)? { get set }

    func apply(
        show: KeyboardShortcut?,
        toggle: KeyboardShortcut?,
        copy: KeyboardShortcut?,
        screenshotOCR: KeyboardShortcut?
    )

    /// 暂停快捷键功能（用于录制快捷键时避免触发现有快捷键）
    func suspendHotkeys()

    /// 恢复快捷键功能
    func resumeHotkeys()
}

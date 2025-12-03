import Foundation

protocol OpenAIStreamingClient {
    func stream(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [OpenAIClient.RequestBody.Message],
        parameters: AITaskParameters,
        proxy: HTTPClient.ProxySettings?
    ) -> AsyncThrowingStream<String, Error>
}

protocol PreferencesPersisting {
    func load() -> Preferences?
    func save(_ preferences: Preferences)
}

protocol HotkeyManaging: AnyObject {
    var onShowWindow: (() -> Void)? { get set }
    var onToggleMode: (() -> Void)? { get set }
    var onQuickCopy: (() -> Void)? { get set }

    func apply(
        show: KeyboardShortcut?,
        toggle: KeyboardShortcut?,
        copy: KeyboardShortcut?
    )

    /// 暂停快捷键功能（用于录制快捷键时避免触发现有快捷键）
    func suspendHotkeys()

    /// 恢复快捷键功能
    func resumeHotkeys()
}

import Foundation
import XCTest
@testable import AITranslator

@MainActor
final class AppViewModelTranslationTests: XCTestCase {
    func testFreeProviderRoutesTranslationToDeepL() async {
        let deepL = DeepLServiceSpy(results: [.success("Hello")])
        let preferences = Preferences(
            translationProvider: .deepLFree,
            deepLAPIKey: "key",
            defaultTargetLanguage: "en"
        )
        let viewModel = makeViewModel(preferences: preferences, deepL: deepL)
        viewModel.onInputChanged("你好")
        viewModel.restoreLanguages(source: "zh-CN", target: "en")

        viewModel.send()
        await waitUntil { !viewModel.session.isStreaming }

        XCTAssertEqual(viewModel.session.output, "Hello")
        XCTAssertNil(viewModel.session.error)
        XCTAssertEqual(deepL.executions.count, 1)
        XCTAssertEqual(deepL.executions.first?.context.operation, .translate)
        XCTAssertEqual(deepL.executions.first?.context.configuration.baseURL, "https://api-free.deepl.com")
        XCTAssertEqual(viewModel.historyManager.records.first?.provider, .deepLCompatible)
        XCTAssertEqual(viewModel.historyManager.records.first?.service, "DeepL API Free")
    }

    func testProviderCapabilitiesAndModeSwitching() {
        let freeViewModel = makeViewModel(
            preferences: Preferences(translationProvider: .deepLFree, deepLAPIKey: "key")
        )
        XCTAssertFalse(freeViewModel.isPolishAvailable)
        XCTAssertFalse(freeViewModel.isSummarizeAvailable)
        freeViewModel.setMode(.polish)
        XCTAssertEqual(freeViewModel.session.mode, .translate)

        let proViewModel = makeViewModel(
            preferences: Preferences(translationProvider: .deepLPro, deepLAPIKey: "key")
        )
        XCTAssertTrue(proViewModel.isPolishAvailable)
        XCTAssertFalse(proViewModel.isSummarizeAvailable)
        proViewModel.setMode(.polish, autoSend: false)
        XCTAssertEqual(proViewModel.session.mode, .polish)

        let openAIViewModel = makeViewModel(
            preferences: Preferences(translationProvider: .openAI, apiKey: "key")
        )
        XCTAssertTrue(openAIViewModel.isPolishAvailable)
        XCTAssertTrue(openAIViewModel.isSummarizeAvailable)
    }

    func testProPolishUsesWrite() async {
        let deepL = DeepLServiceSpy(results: [.success("This is a test.")])
        let preferences = Preferences(
            translationProvider: .deepLPro,
            deepLAPIKey: "key"
        )
        let viewModel = makeViewModel(preferences: preferences, deepL: deepL)
        viewModel.setMode(.polish, autoSend: false)
        viewModel.setSourceLang("en")
        viewModel.onInputChanged("This are a test.")

        viewModel.send()
        await waitUntil { !viewModel.session.isStreaming }

        XCTAssertEqual(viewModel.session.output, "This is a test.")
        XCTAssertEqual(deepL.executions.first?.context.operation, .rephrase)
        XCTAssertEqual(deepL.executions.first?.context.targetLanguage, "en")
    }

    func testChunkFailureKeepsPartialOutputAndRetriesFromFailure() async {
        let deepL = DeepLServiceSpy(
            chunks: [
                DeepLTextChunk(text: "first", separatorAfter: " "),
                DeepLTextChunk(text: "second", separatorAfter: "")
            ],
            results: [
                .success("ONE"),
                .failure(DeepLServiceError(statusCode: 400, message: "bad request")),
                .success("TWO")
            ]
        )
        let preferences = Preferences(
            translationProvider: .deepLCustom,
            appLanguage: .en,
            deepLBaseURL: "https://example.com",
            deepLAPIFamily: .legacyDeepLX
        )
        let viewModel = makeViewModel(preferences: preferences, deepL: deepL)
        viewModel.onInputChanged("first second")
        viewModel.restoreLanguages(source: "en", target: "de")

        viewModel.send()
        await waitUntil { !viewModel.session.isStreaming }

        XCTAssertEqual(viewModel.session.output, "ONE ")
        // 服务层只回传结构化 reason，文案由 AppViewModel 按当前语言映射
        XCTAssertEqual(viewModel.session.error, "Chunk 2/2 failed: bad request")
        XCTAssertTrue(viewModel.canRetryFromFailure)
        XCTAssertEqual(deepL.executions.map(\.text), ["first", "second"])

        viewModel.retryFromFailure()
        await waitUntil { !viewModel.session.isStreaming }

        XCTAssertEqual(viewModel.session.output, "ONE TWO")
        XCTAssertNil(viewModel.session.error)
        XCTAssertFalse(viewModel.canRetryFromFailure)
        XCTAssertEqual(deepL.executions.map(\.text), ["first", "second", "second"])
    }

    func testOpenAIProviderStreamsDeltasAndRecordsHistory() async {
        let openai = OpenAIClientSpy(deltas: ["Hel", "lo"])
        let preferences = Preferences(
            translationProvider: .openAI,
            model: "test-model",
            apiKey: "key"
        )
        let viewModel = makeViewModel(preferences: preferences, openai: openai)
        viewModel.onInputChanged("你好")
        viewModel.restoreLanguages(source: "zh-CN", target: "en")

        viewModel.send()
        await waitUntil { !viewModel.session.isStreaming }

        XCTAssertEqual(viewModel.session.output, "Hello")
        XCTAssertNil(viewModel.session.error)
        XCTAssertEqual(viewModel.translationTotalUnits, 0)
        XCTAssertFalse(viewModel.canRetryFromFailure)
        XCTAssertEqual(openai.capturedMessages.count, 2)
        XCTAssertEqual(openai.capturedMessages.first?.role, "system")
        XCTAssertTrue(openai.capturedMessages.last?.content.hasPrefix("Translate from") == true)
        XCTAssertTrue(openai.capturedMessages.last?.content.hasSuffix("你好") == true)
        XCTAssertEqual(viewModel.historyManager.records.first?.provider, .openAICompatible)
        XCTAssertEqual(viewModel.historyManager.records.first?.service, "test-model")
    }

    private func makeViewModel(
        preferences: Preferences,
        deepL: DeepLServiceSpy? = nil,
        openai: OpenAIClientSpy? = nil
    ) -> AppViewModel {
        AppViewModel(
            openai: openai ?? OpenAIClientSpy(),
            deepL: deepL ?? DeepLServiceSpy(),
            preferencesStore: PreferencesStoreSpy(preferences: preferences),
            hotkeys: HotkeyManagerSpy()
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
        XCTAssertTrue(condition(), "Timed out waiting for asynchronous state")
    }
}

@MainActor
private final class DeepLServiceSpy: DeepLServicing {
    struct Execution {
        let text: String
        let context: DeepLRequestContext
    }

    var chunks: [DeepLTextChunk]?
    var results: [Result<String, Error>]
    private(set) var executions: [Execution] = []

    init(
        chunks: [DeepLTextChunk]? = nil,
        results: [Result<String, Error>] = []
    ) {
        self.chunks = chunks
        self.results = results
    }

    func prepareChunks(text: String, context: DeepLRequestContext) throws -> [DeepLTextChunk] {
        chunks ?? [DeepLTextChunk(text: text, separatorAfter: "")]
    }

    func execute(
        text: String,
        context: DeepLRequestContext,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> String {
        executions.append(Execution(text: text, context: context))
        guard !results.isEmpty else { return text }
        return try results.removeFirst().get()
    }

    func testConnection(
        configuration: DeepLServiceConfiguration,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> DeepLConnectionTestResult {
        DeepLConnectionTestResult(translatedText: "Hallo", rephrasedText: nil)
    }
}

private final class OpenAIClientSpy: OpenAIStreamingClient {
    private(set) var capturedMessages: [OpenAIClient.RequestBody.Message] = []
    private let deltas: [String]

    init(deltas: [String] = []) {
        self.deltas = deltas
    }

    func stream(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [OpenAIClient.RequestBody.Message],
        parameters: AITaskParameters,
        proxy: HTTPClient.ProxySettings?
    ) -> AsyncThrowingStream<String, Error> {
        capturedMessages = messages
        let deltas = self.deltas
        return AsyncThrowingStream { continuation in
            for delta in deltas {
                continuation.yield(delta)
            }
            continuation.finish()
        }
    }
}

private final class PreferencesStoreSpy: PreferencesPersisting {
    private var preferences: Preferences?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func load() -> Preferences? {
        preferences
    }

    func save(_ preferences: Preferences) {
        self.preferences = preferences
    }
}

@MainActor
private final class HotkeyManagerSpy: HotkeyManaging {
    var onShowWindow: (() -> Void)?
    var onToggleMode: (() -> Void)?
    var onQuickCopy: (() -> Void)?

    func apply(
        show: KeyboardShortcut?,
        toggle: KeyboardShortcut?,
        copy: KeyboardShortcut?
    ) {}

    func suspendHotkeys() {}
    func resumeHotkeys() {}
}

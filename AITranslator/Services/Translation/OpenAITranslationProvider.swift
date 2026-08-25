import Foundation

/// OpenAI 兼容提供方：逐 token 流式输出
@MainActor
struct OpenAITranslationProvider: TranslationProvider {
    private let client: OpenAIStreamingClient
    private let preferences: Preferences

    init(client: OpenAIStreamingClient, preferences: Preferences) {
        self.client = client
        self.preferences = preferences
    }

    var identity: TranslationProviderIdentity {
        TranslationProviderIdentity(historyProvider: .openAICompatible, service: preferences.model)
    }

    var capabilities: TranslationCapabilities {
        TranslationCapabilities(supportsPolish: true, supportsSummarize: true)
    }

    var delivery: TranslationDelivery { .incrementalStream }

    func events(for request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, Error> {
        let deltas = client.stream(
            baseURL: preferences.baseURL,
            apiKey: preferences.apiKey,
            model: preferences.model,
            messages: Self.messages(for: request),
            parameters: AITaskParameters.parameters(for: request.mode),
            proxy: request.proxy
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await delta in deltas {
                        continuation.yield(.delta(delta))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Prompts

    private static func messages(for request: TranslationRequest) -> [OpenAIClient.RequestBody.Message] {
        let sourceName = LanguageUtils.displayName(for: request.sourceLanguage)
        let targetName = LanguageUtils.displayName(for: request.targetLanguage)

        let systemPrompt: String
        let instruction: String

        switch request.mode {
        case .polish:
            systemPrompt = "You are an expert language editor."
                + " Reply with only the edited text, without any explanations or notes."
            instruction = "Polish the following \(sourceName) text to improve clarity"
                + " and naturalness while preserving the original meaning:"

        case .translate:
            systemPrompt = "You are a professional translator."
                + " Reply with only the translated text, without any explanations or notes."
            instruction = "Translate from \(sourceName) to \(targetName):"

        case .summarize:
            systemPrompt = "You are a professional text summarizer."
                + " Reply with only the summary, without any explanations or notes."
            instruction = "Summarize the following text in \(targetName), keeping the key information:"
        }

        return [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: "\(instruction)\n\n\(request.input)")
        ]
    }
}

import Foundation

/// DeepL 兼容提供方：按块整段返回，失败可从中断块续传
@MainActor
struct DeepLTranslationProvider: TranslationProvider {
    /// 续传句柄：内部结构仅本提供方可见
    private struct ResumeToken: TranslationResumeToken {
        let request: TranslationRequest
        let context: DeepLRequestContext
        let chunks: [DeepLTextChunk]
        let nextChunkIndex: Int
        let completedOutput: String
    }

    private let client: DeepLServicing
    private let preferences: Preferences

    init(client: DeepLServicing, preferences: Preferences) {
        self.client = client
        self.preferences = preferences
    }

    var identity: TranslationProviderIdentity {
        let service: String
        switch preferences.translationProvider {
        case .deepLFree:
            service = "DeepL API Free"
        case .deepLPro:
            service = "DeepL API Pro"
        case .deepLCustom:
            service = preferences.resolvedDeepLAPIFamily == .legacyDeepLX
                ? "Legacy DeepLX"
                : "Custom DeepL /v2"
        case .openAI:
            service = "DeepL"
        }
        return TranslationProviderIdentity(historyProvider: .deepLCompatible, service: service)
    }

    var capabilities: TranslationCapabilities {
        TranslationCapabilities(
            supportsPolish: preferences.deepLSupportsWrite,
            supportsSummarize: false
        )
    }

    var delivery: TranslationDelivery { .chunkedBatches }

    func events(for request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, Error> {
        AsyncThrowingStream { continuation in
            let context: DeepLRequestContext
            let chunks: [DeepLTextChunk]
            do {
                context = try makeContext(for: request)
                chunks = try client.prepareChunks(text: request.input, context: context)
            } catch {
                continuation.finish(throwing: failure(from: error))
                return
            }

            guard !chunks.isEmpty else {
                continuation.finish()
                return
            }

            run(
                chunks: chunks,
                startIndex: 0,
                completedOutput: "",
                context: context,
                request: request,
                continuation: continuation
            )
        }
    }

    func resumeEvents(
        from token: any TranslationResumeToken,
        request: TranslationRequest
    ) -> AsyncThrowingStream<TranslationEvent, Error>? {
        guard let token = token as? ResumeToken,
              token.request == request,
              let context = try? makeContext(for: request),
              token.context == context else {
            return nil
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.reset(token.completedOutput))
            run(
                chunks: token.chunks,
                startIndex: token.nextChunkIndex,
                completedOutput: token.completedOutput,
                context: context,
                request: request,
                continuation: continuation
            )
        }
    }

    // MARK: - Execution

    private func run(
        chunks: [DeepLTextChunk],
        startIndex: Int,
        completedOutput: String,
        context: DeepLRequestContext,
        request: TranslationRequest,
        continuation: AsyncThrowingStream<TranslationEvent, Error>.Continuation
    ) {
        continuation.yield(.progress(completed: startIndex, total: chunks.count))

        let task = Task {
            var output = completedOutput
            for index in startIndex..<chunks.count {
                do {
                    let translated = try await client.execute(
                        text: chunks[index].text,
                        context: context,
                        proxy: request.proxy
                    )
                    let delta = translated + chunks[index].separatorAfter
                    output.append(delta)
                    continuation.yield(.delta(delta))
                    continuation.yield(.progress(completed: index + 1, total: chunks.count))
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                    return
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish(throwing: error)
                    return
                } catch {
                    continuation.finish(throwing: TranslationFailure(
                        reason: .chunkFailure(
                            chunkNumber: index + 1,
                            total: chunks.count,
                            underlying: error.localizedDescription
                        ),
                        resumeToken: ResumeToken(
                            request: request,
                            context: context,
                            chunks: chunks,
                            nextChunkIndex: index,
                            completedOutput: output
                        )
                    ))
                    return
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }

    // MARK: - Request context

    private func makeContext(for request: TranslationRequest) throws -> DeepLRequestContext {
        let operation: DeepLTextOperation
        switch request.mode {
        case .translate:
            operation = .translate
        case .polish:
            guard preferences.deepLSupportsWrite else {
                throw TranslationFailure(reason: .polishUnavailable)
            }
            operation = .rephrase
        case .summarize:
            throw TranslationFailure(reason: .summarizeUnavailable)
        }

        return DeepLRequestContext(
            configuration: DeepLServiceConfiguration(
                baseURL: preferences.resolvedDeepLBaseURL,
                apiKey: preferences.deepLAPIKey,
                apiFamily: preferences.resolvedDeepLAPIFamily,
                supportsWrite: preferences.deepLSupportsWrite
            ),
            operation: operation,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.mode == .polish ? request.sourceLanguage : request.targetLanguage
        )
    }

    // MARK: - Errors

    private func failure(from error: Error) -> TranslationFailure {
        if let failure = error as? TranslationFailure {
            return failure
        }
        return TranslationFailure(reason: .underlying(error.localizedDescription))
    }
}

import Foundation

struct OpenAIClient: OpenAIStreamingClient {
    struct RequestBody: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let temperature: Double?
        let top_p: Double?
        let frequency_penalty: Double?
        let presence_penalty: Double?
        let stream: Bool
        let messages: [Message]
    }

    /// 复用 JSONEncoder 和 JSONDecoder 实例，避免每次请求都创建新实例
    /// 这是一个性能优化：编码器/解码器的创建有一定开销
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    func stream(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [RequestBody.Message],
        parameters: AITaskParameters = .default,
        proxy: HTTPClient.ProxySettings? = nil,
        userAgent: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if let userAgent, !userAgent.isEmpty {
                        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                    }
                    // 部分兼容服务（如 GitHub Copilot）对推理模型返回
                    // HTTP 400 "Unsupported parameter: 'temperature' ..."；
                    // 与官方/LiteLLM 的 drop_params 处理一致：去掉该参数后重试一次。
                    var params = ModelConstraints.adjustParameters(model: model, original: parameters)
                    for attempt in 0...1 {
                        let body = RequestBody(
                            model: model,
                            temperature: params.temperature,
                            top_p: params.topP,
                            frequency_penalty: params.frequencyPenalty,
                            presence_penalty: params.presencePenalty,
                            stream: true,
                            messages: messages
                        )
                        request.httpBody = try Self.encoder.encode(body)
                        let (bytes, response) = try await HTTPClient.bytes(for: request, proxy: proxy)
                        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                            var data = Data()
                            for try await chunk in bytes {
                                data.append(chunk)
                            }
                            let message: String = {
                                struct OpenAIErrorEnvelope: Decodable {
                                    struct OpenAIError: Decodable { let message: String? }
                                    let error: OpenAIError?
                                }
                                if let obj = try? Self.decoder.decode(OpenAIErrorEnvelope.self, from: data),
                                    let msg = obj.error?.message, !msg.isEmpty {
                                    return msg
                                }
                                if let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    return "HTTP \(http.statusCode): \(text)"
                                }
                                return "HTTP \(http.statusCode)"
                            }()
                            if attempt == 0,
                                let name = Self.unsupportedParamName(in: message),
                                let reduced = Self.paramsDropping(name, from: params) {
                                params = reduced
                                continue
                            }
                            throw NSError(domain: "OpenAIClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                        }
                        for try await line in bytes.lines {
                            if let delta = SSEParser.parseDelta(from: line), !delta.isEmpty {
                                continuation.yield(delta)
                            }
                        }
                        continuation.finish()
                        return
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - 不支持参数的自适应

extension OpenAIClient {
    /// 从 400 错误信息中提取服务端声明不支持/无法识别的参数名。
    /// 覆盖 OpenAI/Azure/GitHub Copilot 及多数兼容网关的措辞：
    /// - `Unsupported parameter: 'temperature' is not supported with this model`
    /// - `Unsupported value: 'temperature' does not support 0 with this model`
    /// - `Unrecognized request argument supplied: temperature`
    static func unsupportedParamName(in message: String) -> String? {
        let patterns = [
            #"Unsupported (?:parameter|value): '([A-Za-z0-9_.-]+)'"#,
            #"Unrecognized request argument supplied: ([A-Za-z0-9_.-]+)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(message.startIndex..., in: message)
            guard let match = regex.firstMatch(in: message, range: range),
                match.numberOfRanges > 1,
                let captured = Range(match.range(at: 1), in: message) else { continue }
            return String(message[captured])
        }
        return nil
    }

    /// 把服务端拒绝的参数从请求参数中移除；返回 nil 表示该参数不在可控范围或本就未设置。
    static func paramsDropping(_ name: String, from params: AITaskParameters) -> AITaskParameters? {
        switch name {
        case "temperature" where params.temperature != nil:
            return AITaskParameters(temperature: nil, topP: params.topP, frequencyPenalty: params.frequencyPenalty, presencePenalty: params.presencePenalty, reasoningEffort: params.reasoningEffort, textVerbosity: params.textVerbosity)
        case "top_p" where params.topP != nil:
            return AITaskParameters(temperature: params.temperature, topP: nil, frequencyPenalty: params.frequencyPenalty, presencePenalty: params.presencePenalty, reasoningEffort: params.reasoningEffort, textVerbosity: params.textVerbosity)
        case "frequency_penalty" where params.frequencyPenalty != nil:
            return AITaskParameters(temperature: params.temperature, topP: params.topP, frequencyPenalty: nil, presencePenalty: params.presencePenalty, reasoningEffort: params.reasoningEffort, textVerbosity: params.textVerbosity)
        case "presence_penalty" where params.presencePenalty != nil:
            return AITaskParameters(temperature: params.temperature, topP: params.topP, frequencyPenalty: params.frequencyPenalty, presencePenalty: nil, reasoningEffort: params.reasoningEffort, textVerbosity: params.textVerbosity)
        default:
            return nil
        }
    }
}

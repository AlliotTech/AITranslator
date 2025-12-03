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
        proxy: HTTPClient.ProxySettings? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let adjustedParams = ModelConstraints.adjustParameters(model: model, original: parameters)
                    let body = RequestBody(
                        model: model,
                        temperature: adjustedParams.temperature,
                        top_p: adjustedParams.topP,
                        frequency_penalty: adjustedParams.frequencyPenalty,
                        presence_penalty: adjustedParams.presencePenalty,
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
                        throw NSError(domain: "OpenAIClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                    }
                    for try await line in bytes.lines {
                        if let delta = SSEParser.parseDelta(from: line), !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
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

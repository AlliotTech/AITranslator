import Foundation

/// OpenAI 兼容服务 `/v1/models` 模型列表客户端。
enum ModelListClient {
    private struct ModelsEnvelope: Decodable {
        struct Model: Decodable { let id: String? }
        let data: [Model]?
    }

    /// 从聊天补全接口地址推导模型列表地址。
    ///
    /// 规则：路径以 `/chat/completions` 结尾时替换为 `/models`，
    /// 否则去掉尾部斜杠后追加 `/models`；query 与 fragment 一并丢弃。
    /// 示例：
    /// - `https://api.openai.com/v1/chat/completions` → `https://api.openai.com/v1/models`
    /// - `http://127.0.0.1:3425/v1/chat/completions` → `http://127.0.0.1:3425/v1/models`
    /// - `https://api.deepseek.com` → `https://api.deepseek.com/models`
    /// - `http://localhost:11434/v1/` → `http://localhost:11434/v1/models`
    static func modelsURL(fromEndpoint endpoint: String) -> URL? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
            components.scheme != nil,
            components.host != nil else { return nil }

        var path = components.path
        if path.hasSuffix("/chat/completions") {
            path.removeLast("/chat/completions".count)
        }
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        if path == "/" { path = "" }

        components.path = path + "/models"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    /// 拉取模型列表，返回去重并按字典序排序的模型 id。
    static func fetchModels(
        baseURL: String,
        apiKey: String,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> [String] {
        guard let url = modelsURL(fromEndpoint: baseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await HTTPClient.data(for: request, proxy: proxy)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data))?.error?.message
            throw NSError(
                domain: "ModelListClient",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message ?? "HTTP \(http.statusCode)"]
            )
        }

        let envelope = try JSONDecoder().decode(ModelsEnvelope.self, from: data)
        var ids = Set<String>()
        ids.formUnion(envelope.data?.compactMap(\.id).filter { !$0.isEmpty } ?? [])
        return ids.sorted()
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    struct Payload: Decodable { let message: String? }
    let error: Payload?
}

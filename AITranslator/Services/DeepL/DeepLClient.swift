import Foundation

struct DeepLServiceConfiguration: Equatable, Sendable {
    let baseURL: String
    let apiKey: String
    let apiFamily: DeepLAPIFamily
    let supportsWrite: Bool
}

enum DeepLTextOperation: String, Equatable, Sendable {
    case translate
    case rephrase
}

struct DeepLRequestContext: Equatable, Sendable {
    let configuration: DeepLServiceConfiguration
    let operation: DeepLTextOperation
    let sourceLanguage: String
    let targetLanguage: String
}

struct DeepLTextChunk: Equatable, Sendable {
    let text: String
    let separatorAfter: String
}

struct DeepLConnectionTestResult: Equatable, Sendable {
    let translatedText: String
    let rephrasedText: String?
}

struct DeepLServiceError: LocalizedError, Equatable, Sendable {
    let statusCode: Int?
    let message: String

    var errorDescription: String? { message }

    var isRetryable: Bool {
        guard let statusCode else { return false }
        return statusCode == 429 || statusCode == 529 || (500...599).contains(statusCode)
    }
}

enum DeepLEndpointResolver {
    static func url(
        baseURL: String,
        family: DeepLAPIFamily,
        operation: DeepLTextOperation
    ) throws -> URL {
        let rawBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: rawBase),
              components.query == nil,
              components.fragment == nil,
              components.url != nil else {
            throw URLError(.badURL)
        }

        var basePath = normalizedBasePath(components.path, family: family)
        while basePath.count > 1 && basePath.hasSuffix("/") {
            basePath.removeLast()
        }
        if basePath == "/" {
            basePath = ""
        }

        let endpointPath: String
        switch (family, operation) {
        case (.officialV2, .translate):
            endpointPath = "/v2/translate"
        case (.officialV2, .rephrase):
            endpointPath = "/v2/write/rephrase"
        case (.legacyDeepLX, .translate):
            endpointPath = "/translate"
        case (.legacyDeepLX, .rephrase):
            throw DeepLServiceError(
                statusCode: nil,
                message: "Legacy DeepLX does not support DeepL Write."
            )
        }

        components.path = basePath + endpointPath
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private static func normalizedBasePath(
        _ rawPath: String,
        family: DeepLAPIFamily
    ) -> String {
        var path = rawPath
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }

        let knownSuffixes: [String]
        switch family {
        case .officialV2:
            knownSuffixes = ["/v2/write/rephrase", "/v2/translate", "/v2"]
        case .legacyDeepLX:
            knownSuffixes = ["/translate"]
        }

        if let suffix = knownSuffixes.first(where: { path.hasSuffix($0) }) {
            path.removeLast(suffix.count)
        }
        return path
    }
}

enum DeepLLanguageMapper {
    static func sourceCode(for appCode: String, family: DeepLAPIFamily) -> String {
        let standardized = LanguageUtils.standardize(code: appCode).lowercased()
        switch standardized {
        case "zh-cn", "zh": return "zh"
        default: return standardized
        }
    }

    static func targetCode(for appCode: String, family: DeepLAPIFamily) -> String {
        let standardized = LanguageUtils.standardize(code: appCode).lowercased()
        switch family {
        case .legacyDeepLX:
            switch standardized {
            case "zh-cn", "zh": return "zh"
            case "en", "en-us", "en-gb": return "en"
            default: return standardized
            }
        case .officialV2:
            switch standardized {
            case "zh-cn", "zh": return "zh-Hans"
            case "en", "en-us": return "en-US"
            case "en-gb": return "en-GB"
            default: return standardized
            }
        }
    }

    static func writeTargetCode(for appCode: String) -> String {
        targetCode(for: appCode, family: .officialV2)
    }
}

struct DeepLClient: DeepLServicing {
    typealias DataLoader = (URLRequest, HTTPClient.ProxySettings?) async throws -> (Data, URLResponse)

    private enum Limits {
        static let officialTranslateBodyBytes = 128 * 1024
        static let officialWriteBodyBytes = 10 * 1024
        // Legacy DeepLX deployments do not share a stable published limit. Keep requests
        // deliberately small and let the caller make visible progress across chunks.
        static let legacyTranslateBodyBytes = 24 * 1024
        static let maxAttempts = 3
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private let dataLoader: DataLoader

    init(
        dataLoader: @escaping DataLoader = { request, proxy in
            try await HTTPClient.data(for: request, proxy: proxy)
        }
    ) {
        self.dataLoader = dataLoader
    }

    func prepareChunks(text: String, context: DeepLRequestContext) throws -> [DeepLTextChunk] {
        guard !text.isEmpty else { return [] }

        let bodyLimit = requestBodyLimit(for: context)
        let units = textUnits(from: text)
        var chunks: [DeepLTextChunk] = []
        var current = ""

        for unit in units {
            let candidate = current + unit
            if try requestBodySize(text: candidate, context: context) <= bodyLimit {
                current = candidate
                continue
            }

            if !current.isEmpty {
                appendFinalizedChunk(current, to: &chunks)
                current = ""
            }

            if try requestBodySize(text: unit, context: context) <= bodyLimit {
                current = unit
            } else {
                let hardChunks = try splitOversizedUnit(unit, context: context, bodyLimit: bodyLimit)
                if let last = hardChunks.last {
                    chunks.append(contentsOf: hardChunks.dropLast())
                    current = last.text + last.separatorAfter
                }
            }
        }

        if !current.isEmpty {
            appendFinalizedChunk(current, to: &chunks)
        }

        return chunks.filter { !$0.text.isEmpty }
    }

    func execute(
        text: String,
        context: DeepLRequestContext,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> String {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await executeOnce(text: text, context: context, proxy: proxy)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch {
                attempt += 1
                guard attempt < Limits.maxAttempts, isRetryable(error) else { throw error }
                let delay = UInt64(500 * (1 << (attempt - 1))) * 1_000_000
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }

    func testConnection(
        configuration: DeepLServiceConfiguration,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> DeepLConnectionTestResult {
        let translateContext = DeepLRequestContext(
            configuration: configuration,
            operation: .translate,
            sourceLanguage: "en",
            targetLanguage: "de"
        )
        let translated = try await execute(text: "Hello.", context: translateContext, proxy: proxy)

        var rephrased: String?
        if configuration.supportsWrite && configuration.apiFamily == .officialV2 {
            let writeContext = DeepLRequestContext(
                configuration: configuration,
                operation: .rephrase,
                sourceLanguage: "en",
                targetLanguage: "en"
            )
            rephrased = try await execute(text: "This are a test.", context: writeContext, proxy: proxy)
        }

        return DeepLConnectionTestResult(translatedText: translated, rephrasedText: rephrased)
    }

    private func executeOnce(
        text: String,
        context: DeepLRequestContext,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> String {
        let request = try buildRequest(text: text, context: context)
        let (data, response) = try await dataLoader(request, proxy)
        guard let http = response as? HTTPURLResponse else {
            throw DeepLServiceError(statusCode: nil, message: "The translation service returned an invalid response.")
        }

        guard (200...299).contains(http.statusCode) else {
            throw serviceError(statusCode: http.statusCode, data: data)
        }

        switch (context.configuration.apiFamily, context.operation) {
        case (.legacyDeepLX, .translate):
            let envelope: LegacyEnvelope
            do {
                envelope = try Self.decoder.decode(LegacyEnvelope.self, from: data)
            } catch {
                throw DeepLServiceError(statusCode: http.statusCode, message: "The Legacy DeepLX response could not be decoded.")
            }
            guard envelope.code == 200, let translated = envelope.data else {
                // DeepLX 成功响应通常不带 message，失败响应才带
                let message = envelope.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw DeepLServiceError(
                    statusCode: envelope.code,
                    message: message.isEmpty ? "Legacy DeepLX translation failed." : message
                )
            }
            return translated

        case (.officialV2, .translate):
            let envelope: TranslationEnvelope
            do {
                envelope = try Self.decoder.decode(TranslationEnvelope.self, from: data)
            } catch {
                throw DeepLServiceError(statusCode: http.statusCode, message: "The DeepL translation response could not be decoded.")
            }
            guard !envelope.translations.isEmpty else {
                throw DeepLServiceError(statusCode: http.statusCode, message: "The DeepL translation response was empty.")
            }
            return envelope.translations.map(\.text).joined(separator: "\n")

        case (.officialV2, .rephrase):
            let envelope: ImprovementEnvelope
            do {
                envelope = try Self.decoder.decode(ImprovementEnvelope.self, from: data)
            } catch {
                throw DeepLServiceError(statusCode: http.statusCode, message: "The DeepL Write response could not be decoded.")
            }
            guard !envelope.improvements.isEmpty else {
                throw DeepLServiceError(statusCode: http.statusCode, message: "The DeepL Write response was empty.")
            }
            return envelope.improvements.map(\.text).joined(separator: "\n")

        case (.legacyDeepLX, .rephrase):
            throw DeepLServiceError(statusCode: nil, message: "Legacy DeepLX does not support DeepL Write.")
        }
    }

    private func buildRequest(text: String, context: DeepLRequestContext) throws -> URLRequest {
        let endpoint = try endpointURL(for: context)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiKey = context.configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try requestBody(text: text, context: context)
        return request
    }

    private func endpointURL(for context: DeepLRequestContext) throws -> URL {
        try DeepLEndpointResolver.url(
            baseURL: context.configuration.baseURL,
            family: context.configuration.apiFamily,
            operation: context.operation
        )
    }

    private func requestBody(text: String, context: DeepLRequestContext) throws -> Data {
        switch (context.configuration.apiFamily, context.operation) {
        case (.officialV2, .translate):
            return try Self.encoder.encode(OfficialTranslateBody(
                text: [text],
                sourceLang: DeepLLanguageMapper.sourceCode(
                    for: context.sourceLanguage,
                    family: context.configuration.apiFamily
                ),
                targetLang: DeepLLanguageMapper.targetCode(
                    for: context.targetLanguage,
                    family: context.configuration.apiFamily
                )
            ))
        case (.officialV2, .rephrase):
            return try Self.encoder.encode(OfficialWriteBody(
                text: [text],
                targetLang: DeepLLanguageMapper.writeTargetCode(for: context.targetLanguage)
            ))
        case (.legacyDeepLX, .translate):
            return try Self.encoder.encode(LegacyTranslateBody(
                text: text,
                sourceLang: DeepLLanguageMapper.sourceCode(
                    for: context.sourceLanguage,
                    family: context.configuration.apiFamily
                ),
                targetLang: DeepLLanguageMapper.targetCode(
                    for: context.targetLanguage,
                    family: context.configuration.apiFamily
                )
            ))
        case (.legacyDeepLX, .rephrase):
            throw DeepLServiceError(statusCode: nil, message: "Legacy DeepLX does not support DeepL Write.")
        }
    }

    private func requestBodySize(text: String, context: DeepLRequestContext) throws -> Int {
        try requestBody(text: text, context: context).count
    }

    private func requestBodyLimit(for context: DeepLRequestContext) -> Int {
        switch (context.configuration.apiFamily, context.operation) {
        case (.officialV2, .translate): return Limits.officialTranslateBodyBytes
        case (.officialV2, .rephrase): return Limits.officialWriteBodyBytes
        case (.legacyDeepLX, .translate): return Limits.legacyTranslateBodyBytes
        case (.legacyDeepLX, .rephrase): return Limits.officialWriteBodyBytes
        }
    }

    private func textUnits(from text: String) -> [String] {
        let punctuation: Set<Character> = [".", "!", "?", "。", "！", "？", ";", "；"]
        let characters = Array(text)
        var units: [String] = []
        var current = ""
        var index = 0

        while index < characters.count {
            let character = characters[index]
            current.append(character)
            index += 1

            if punctuation.contains(character) {
                while index < characters.count && characters[index].isWhitespace {
                    current.append(characters[index])
                    index += 1
                }
                units.append(current)
                current = ""
            } else if character.isWhitespace {
                while index < characters.count && characters[index].isWhitespace {
                    current.append(characters[index])
                    index += 1
                }
                units.append(current)
                current = ""
            }
        }

        if !current.isEmpty { units.append(current) }
        return units
    }

    private func splitOversizedUnit(
        _ unit: String,
        context: DeepLRequestContext,
        bodyLimit: Int
    ) throws -> [DeepLTextChunk] {
        var remaining = Array(unit)
        var result: [DeepLTextChunk] = []

        while !remaining.isEmpty {
            var low = 1
            var high = remaining.count
            var best = 0

            while low <= high {
                let middle = (low + high) / 2
                let candidate = String(remaining.prefix(middle))
                if try requestBodySize(text: candidate, context: context) <= bodyLimit {
                    best = middle
                    low = middle + 1
                } else {
                    high = middle - 1
                }
            }

            guard best > 0 else {
                throw DeepLServiceError(statusCode: 413, message: "A text segment is too large for the translation service.")
            }

            let piece = String(remaining.prefix(best))
            remaining.removeFirst(best)
            appendFinalizedChunk(piece, to: &result)
        }

        return result
    }

    private func appendFinalizedChunk(_ rawChunk: String, to chunks: inout [DeepLTextChunk]) {
        var content = rawChunk
        var separator = ""
        while let last = content.last, last.isWhitespace {
            separator.insert(last, at: separator.startIndex)
            content.removeLast()
        }

        if content.isEmpty {
            if let lastIndex = chunks.indices.last {
                let previous = chunks[lastIndex]
                chunks[lastIndex] = DeepLTextChunk(
                    text: previous.text,
                    separatorAfter: previous.separatorAfter + separator
                )
            }
            return
        }

        chunks.append(DeepLTextChunk(text: content, separatorAfter: separator))
    }

    private func serviceError(statusCode: Int, data: Data) -> DeepLServiceError {
        if let envelope = try? Self.decoder.decode(ErrorEnvelope.self, from: data),
           let message = envelope.message,
           !message.isEmpty {
            return DeepLServiceError(statusCode: statusCode, message: message)
        }

        if let legacy = try? Self.decoder.decode(LegacyErrorEnvelope.self, from: data),
           !legacy.message.isEmpty {
            return DeepLServiceError(statusCode: statusCode, message: legacy.message)
        }

        if let text = String(data: data, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DeepLServiceError(statusCode: statusCode, message: "HTTP \(statusCode): \(text)")
        }

        let fallback: String
        switch statusCode {
        case 401, 403: fallback = "The translation service rejected the access key."
        case 413: fallback = "The request is too large for the translation service."
        case 429, 529: fallback = "The translation service is rate limiting requests."
        case 456: fallback = "The DeepL quota or cost-control limit has been reached."
        default: fallback = "The translation service returned HTTP \(statusCode)."
        }
        return DeepLServiceError(statusCode: statusCode, message: fallback)
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let serviceError = error as? DeepLServiceError {
            return serviceError.isRetryable
        }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
             .resourceUnavailable, .internationalRoamingOff:
            return true
        default:
            return false
        }
    }
}

private extension DeepLClient {
    struct OfficialTranslateBody: Encodable {
        let text: [String]
        let sourceLang: String
        let targetLang: String

        enum CodingKeys: String, CodingKey {
            case text
            case sourceLang = "source_lang"
            case targetLang = "target_lang"
        }
    }

    struct OfficialWriteBody: Encodable {
        let text: [String]
        let targetLang: String

        enum CodingKeys: String, CodingKey {
            case text
            case targetLang = "target_lang"
        }
    }

    struct LegacyTranslateBody: Encodable {
        let text: String
        let sourceLang: String
        let targetLang: String

        enum CodingKeys: String, CodingKey {
            case text
            case sourceLang = "source_lang"
            case targetLang = "target_lang"
        }
    }

    struct TranslationEnvelope: Decodable {
        struct Translation: Decodable { let text: String }
        let translations: [Translation]
    }

    struct ImprovementEnvelope: Decodable {
        struct Improvement: Decodable { let text: String }
        let improvements: [Improvement]
    }

    struct LegacyEnvelope: Decodable {
        let code: Int
        let message: String?
        let data: String?
    }

    struct ErrorEnvelope: Decodable { let message: String? }

    struct LegacyErrorEnvelope: Decodable {
        let message: String
    }
}

import Foundation
import XCTest
@testable import AITranslator

@MainActor
final class DeepLClientTests: XCTestCase {
    func testLanguageMapping() {
        XCTAssertEqual(DeepLLanguageMapper.sourceCode(for: "zh-CN", family: .officialV2), "zh")
        XCTAssertEqual(DeepLLanguageMapper.targetCode(for: "zh-CN", family: .officialV2), "zh-Hans")
        XCTAssertEqual(DeepLLanguageMapper.targetCode(for: "en", family: .officialV2), "en-US")
        XCTAssertEqual(DeepLLanguageMapper.targetCode(for: "zh-CN", family: .legacyDeepLX), "zh")
        XCTAssertEqual(DeepLLanguageMapper.targetCode(for: "en", family: .legacyDeepLX), "en")
    }

    func testOfficialEndpointResolverAcceptsRootAndEndpointURLs() throws {
        let roots = [
            "https://example.com",
            "https://example.com/",
            "https://example.com/proxy",
            "https://example.com/proxy/v2",
            "https://example.com/proxy/v2/translate"
        ]

        for root in roots {
            let url = try DeepLEndpointResolver.url(
                baseURL: root,
                family: .officialV2,
                operation: .translate
            )
            let expectedPrefix = root.contains("/proxy") ? "/proxy" : ""
            XCTAssertEqual(url.path, expectedPrefix + "/v2/translate")
        }

        let writeURL = try DeepLEndpointResolver.url(
            baseURL: "https://example.com/proxy/v2/write/rephrase",
            family: .officialV2,
            operation: .rephrase
        )
        XCTAssertEqual(writeURL.path, "/proxy/v2/write/rephrase")
    }

    func testLegacyEndpointResolverAcceptsRootAndEndpointURLs() throws {
        for root in ["https://example.com", "https://example.com/translate"] {
            let url = try DeepLEndpointResolver.url(
                baseURL: root,
                family: .legacyDeepLX,
                operation: .translate
            )
            XCTAssertEqual(url.path, "/translate")
        }
    }

    func testChunkingPreservesTextAndBodyLimits() throws {
        let input = String(repeating: "第一句。 Second sentence!\n", count: 900)
        let context = makeContext(
            family: .officialV2,
            operation: .rephrase,
            source: "zh-CN",
            target: "zh-CN"
        )
        let chunks = try DeepLClient().prepareChunks(text: input, context: context)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.map { $0.text + $0.separatorAfter }.joined(), input)

        let encoder = JSONEncoder()
        for chunk in chunks {
            let body = try encoder.encode(OfficialWriteBodyForTest(
                text: [chunk.text],
                targetLang: "zh-Hans"
            ))
            XCTAssertLessThanOrEqual(body.count, 10 * 1024)
        }
    }

    func testOfficialTranslateRequestAndResponse() async throws {
        let recorder = RequestRecorder(responses: [
            .init(statusCode: 200, body: #"{"translations":[{"text":"Hello"}]}"#)
        ])
        let client = DeepLClient(dataLoader: recorder.load)
        let result = try await client.execute(
            text: "你好",
            context: makeContext(
                baseURL: "https://example.com/api/v2/translate",
                apiKey: "secret",
                family: .officialV2,
                operation: .translate,
                source: "zh-CN",
                target: "en"
            ),
            proxy: nil
        )

        XCTAssertEqual(result, "Hello")
        let recordedRequests = await recorder.recordedRequests()
        let request = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(request.url?.path, "/api/v2/translate")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "DeepL-Auth-Key secret")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["source_lang"] as? String, "zh")
        XCTAssertEqual(json["target_lang"] as? String, "en-US")
        XCTAssertEqual(json["text"] as? [String], ["你好"])
    }

    func testOfficialWriteRequestAndResponse() async throws {
        let recorder = RequestRecorder(responses: [
            .init(statusCode: 200, body: #"{"improvements":[{"text":"This is a test."}]}"#)
        ])
        let client = DeepLClient(dataLoader: recorder.load)
        let result = try await client.execute(
            text: "This are a test.",
            context: makeContext(
                baseURL: "https://example.com",
                apiKey: "key",
                family: .officialV2,
                operation: .rephrase,
                source: "en",
                target: "en"
            ),
            proxy: nil
        )

        XCTAssertEqual(result, "This is a test.")
        let recordedRequests = await recorder.recordedRequests()
        let request = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(request.url?.path, "/v2/write/rephrase")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["target_lang"] as? String, "en-US")
        XCTAssertNil(json["source_lang"])
    }

    func testLegacyRequestAndResponse() async throws {
        let recorder = RequestRecorder(responses: [
            .init(statusCode: 200, body: #"{"code":200,"message":"success","data":"Free API"}"#)
        ])
        let client = DeepLClient(dataLoader: recorder.load)
        let result = try await client.execute(
            text: "免费 API",
            context: makeContext(
                baseURL: "https://example.com/translate",
                family: .legacyDeepLX,
                operation: .translate,
                source: "zh-CN",
                target: "en"
            ),
            proxy: nil
        )

        XCTAssertEqual(result, "Free API")
        let recordedRequests = await recorder.recordedRequests()
        let request = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(request.url?.path, "/translate")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["source_lang"] as? String, "zh")
        XCTAssertEqual(json["target_lang"] as? String, "en")
        XCTAssertEqual(json["text"] as? String, "免费 API")
    }

    func testRetriesRetryableResponses() async throws {
        let recorder = RequestRecorder(responses: [
            .init(statusCode: 500, body: #"{"message":"temporary"}"#),
            .init(statusCode: 200, body: #"{"translations":[{"text":"Hallo"}]}"#)
        ])
        let result = try await DeepLClient(dataLoader: recorder.load).execute(
            text: "Hello",
            context: makeContext(
                family: .officialV2,
                operation: .translate,
                source: "en",
                target: "de"
            ),
            proxy: nil
        )

        XCTAssertEqual(result, "Hallo")
        let requestCount = await recorder.requestCount()
        XCTAssertEqual(requestCount, 2)
    }

    func testDoesNotRetryQuotaResponse() async {
        let recorder = RequestRecorder(responses: [
            .init(statusCode: 456, body: #"{"message":"Quota exceeded"}"#)
        ])

        do {
            _ = try await DeepLClient(dataLoader: recorder.load).execute(
                text: "Hello",
                context: makeContext(
                    family: .officialV2,
                    operation: .translate,
                    source: "en",
                    target: "de"
                ),
                proxy: nil
            )
            XCTFail("Expected quota error")
        } catch let error as DeepLServiceError {
            XCTAssertEqual(error.statusCode, 456)
            XCTAssertEqual(error.message, "Quota exceeded")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let requestCount = await recorder.requestCount()
        XCTAssertEqual(requestCount, 1)
    }

    func testConnectionChecksTranslateAndWriteForProConfiguration() async throws {
        let recorder = RequestRecorder(responses: [
            .init(statusCode: 200, body: #"{"translations":[{"text":"Hallo."}]}"#),
            .init(statusCode: 200, body: #"{"improvements":[{"text":"This is a test."}]}"#)
        ])
        let result = try await DeepLClient(dataLoader: recorder.load).testConnection(
            configuration: DeepLServiceConfiguration(
                baseURL: "https://example.com/api",
                apiKey: "key",
                apiFamily: .officialV2,
                supportsWrite: true
            ),
            proxy: nil
        )

        XCTAssertEqual(result.translatedText, "Hallo.")
        XCTAssertEqual(result.rephrasedText, "This is a test.")
        let paths = await recorder.recordedRequests().compactMap { $0.url?.path }
        XCTAssertEqual(paths, ["/api/v2/translate", "/api/v2/write/rephrase"])
    }

    func testCancellationPropagates() async {
        let client = DeepLClient { _, _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            throw URLError(.badServerResponse)
        }
        let task = Task {
            try await client.execute(
                text: "Hello",
                context: makeContext(
                    family: .officialV2,
                    operation: .translate,
                    source: "en",
                    target: "de"
                ),
                proxy: nil
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeContext(
        baseURL: String = "https://example.com",
        apiKey: String = "",
        family: DeepLAPIFamily,
        operation: DeepLTextOperation,
        source: String,
        target: String
    ) -> DeepLRequestContext {
        DeepLRequestContext(
            configuration: DeepLServiceConfiguration(
                baseURL: baseURL,
                apiKey: apiKey,
                apiFamily: family,
                supportsWrite: operation == .rephrase
            ),
            operation: operation,
            sourceLanguage: source,
            targetLanguage: target
        )
    }
}

private struct OfficialWriteBodyForTest: Encodable {
    let text: [String]
    let targetLang: String

    enum CodingKeys: String, CodingKey {
        case text
        case targetLang = "target_lang"
    }
}

private actor RequestRecorder {
    struct StubResponse {
        let statusCode: Int
        let body: String
    }

    private(set) var requests: [URLRequest] = []
    private var responses: [StubResponse]

    init(responses: [StubResponse]) {
        self.responses = responses
    }

    func load(
        request: URLRequest,
        proxy: HTTPClient.ProxySettings?
    ) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }
        let response = responses.removeFirst()
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(response.body.utf8), http)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }

    func requestCount() -> Int {
        requests.count
    }
}

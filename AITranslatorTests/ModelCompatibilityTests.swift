import Foundation
import XCTest
@testable import AITranslator

@MainActor
final class ModelCompatibilityTests: XCTestCase {
    func testOldPreferencesDecodeWithOpenAIDefaults() throws {
        let data = Data(#"{"baseURL":"https://example.com/chat","model":"old-model","apiKey":"old-key"}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: data)

        XCTAssertEqual(preferences.translationProvider, .openAI)
        XCTAssertEqual(preferences.baseURL, "https://example.com/chat")
        XCTAssertEqual(preferences.model, "old-model")
        XCTAssertEqual(preferences.apiKey, "old-key")
        XCTAssertEqual(preferences.deepLBaseURL, "")
        XCTAssertEqual(preferences.deepLAPIKey, "")
        XCTAssertEqual(preferences.deepLAPIFamily, .officialV2)
        XCTAssertEqual(preferences.deepLCustomCapability, .translateOnly)
    }

    func testNewPreferencesRoundTripPreservesDeepLFieldsAndKeys() throws {
        let original = Preferences(
            translationProvider: .deepLCustom,
            baseURL: "https://openai.example.com",
            model: "model",
            apiKey: "openai-key",
            deepLBaseURL: "https://deepl.example.com/proxy",
            deepLAPIKey: "deepl-key",
            deepLAPIFamily: .officialV2,
            deepLCustomCapability: .translateAndWrite
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)

        XCTAssertEqual(decoded.translationProvider, .deepLCustom)
        XCTAssertEqual(decoded.apiKey, "openai-key")
        XCTAssertEqual(decoded.deepLAPIKey, "deepl-key")
        XCTAssertEqual(decoded.deepLBaseURL, "https://deepl.example.com/proxy")
        XCTAssertEqual(decoded.deepLAPIFamily, .officialV2)
        XCTAssertEqual(decoded.deepLCustomCapability, .translateAndWrite)
    }

    func testDeepLURLValidation() {
        XCTAssertTrue(Preferences.isAllowedDeepLBaseURL("https://example.com/path"))
        XCTAssertTrue(Preferences.isAllowedDeepLBaseURL("http://localhost:1188"))
        XCTAssertTrue(Preferences.isAllowedDeepLBaseURL("http://127.0.0.1:1188/translate"))
        XCTAssertTrue(Preferences.isAllowedDeepLBaseURL("http://[::1]:1188"))
        XCTAssertFalse(Preferences.isAllowedDeepLBaseURL("http://example.com"))
        XCTAssertFalse(Preferences.isAllowedDeepLBaseURL("https://example.com/path?token=secret"))
        XCTAssertFalse(Preferences.isAllowedDeepLBaseURL("https://example.com/path#fragment"))
        XCTAssertFalse(Preferences.isAllowedDeepLBaseURL("example.com"))
    }

    func testOldHistoryRecordDecodesModelAsOpenAIService() throws {
        let data = Data(#"{"id":"7E36F352-753A-4C55-89D4-58333E34C889","timestamp":0,"mode":"translate","sourceLang":"en","targetLang":"zh-CN","input":"Hello","output":"你好","model":"legacy-model"}"#.utf8)
        let record = try JSONDecoder().decode(HistoryRecord.self, from: data)

        XCTAssertEqual(record.provider, .openAICompatible)
        XCTAssertEqual(record.service, "legacy-model")
        XCTAssertEqual(record.model, "legacy-model")
    }

    func testNewHistoryRecordRoundTrip() throws {
        let original = HistoryRecord(
            mode: .polish,
            sourceLang: "en",
            targetLang: "en",
            input: "This are a test.",
            output: "This is a test.",
            provider: .deepLCompatible,
            service: "DeepL API Pro"
        )

        let decoded = try JSONDecoder().decode(
            HistoryRecord.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded, original)
    }
}

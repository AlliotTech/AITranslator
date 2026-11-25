import Foundation
import XCTest
@testable import AITranslator

@MainActor
final class ModelListClientTests: XCTestCase {
    func testModelsURLReplacesChatCompletionsSuffix() {
        XCTAssertEqual(
            ModelListClient.modelsURL(fromEndpoint: "https://api.openai.com/v1/chat/completions")?.absoluteString,
            "https://api.openai.com/v1/models"
        )
        XCTAssertEqual(
            ModelListClient.modelsURL(fromEndpoint: "http://127.0.0.1:3425/v1/chat/completions")?.absoluteString,
            "http://127.0.0.1:3425/v1/models"
        )
    }

    func testModelsURLAppendsModelsToBasePaths() {
        XCTAssertEqual(
            ModelListClient.modelsURL(fromEndpoint: "https://api.deepseek.com")?.absoluteString,
            "https://api.deepseek.com/models"
        )
        XCTAssertEqual(
            ModelListClient.modelsURL(fromEndpoint: "https://api.deepseek.com/v1")?.absoluteString,
            "https://api.deepseek.com/v1/models"
        )
        XCTAssertEqual(
            ModelListClient.modelsURL(fromEndpoint: "http://localhost:11434/v1/")?.absoluteString,
            "http://localhost:11434/v1/models"
        )
    }

    func testModelsURLDropsQueryAndFragment() {
        XCTAssertEqual(
            ModelListClient.modelsURL(fromEndpoint: "https://example.com/v1/chat/completions?api-key=x#frag")?.absoluteString,
            "https://example.com/v1/models"
        )
    }

    func testModelsURLTrimsWhitespace() {
        XCTAssertEqual(
            ModelListClient.modelsURL(fromEndpoint: "  https://api.openai.com/v1/chat/completions  ")?.absoluteString,
            "https://api.openai.com/v1/models"
        )
    }

    func testModelsURLRejectsInputWithoutScheme() {
        XCTAssertNil(ModelListClient.modelsURL(fromEndpoint: "example.com/v1/chat/completions"))
        XCTAssertNil(ModelListClient.modelsURL(fromEndpoint: "not a url"))
        XCTAssertNil(ModelListClient.modelsURL(fromEndpoint: ""))
    }
}

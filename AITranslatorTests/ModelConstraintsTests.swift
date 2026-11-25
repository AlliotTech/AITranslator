import Foundation
import XCTest

@testable import AITranslator

final class ModelConstraintsTests: XCTestCase {
    private let sampling = AITaskParameters(
        temperature: 0.3,
        topP: 1.0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0,
        reasoningEffort: nil,
        textVerbosity: nil
    )

    func testReasoningModelsDropSamplingParams() {
        for model in ["gpt-5", "gpt-5-mini", "gpt-5.6", "openai/gpt-5.6", "o1", "o1-mini", "o3-mini", "o4-mini", "azure/o3"] {
            let adjusted = ModelConstraints.adjustParameters(model: model, original: sampling)
            XCTAssertNil(adjusted.temperature, model)
            XCTAssertNil(adjusted.topP, model)
            XCTAssertNil(adjusted.frequencyPenalty, model)
            XCTAssertNil(adjusted.presencePenalty, model)
        }
    }

    func testNonReasoningModelsKeepSamplingParams() {
        let adjusted = ModelConstraints.adjustParameters(model: "gpt-4o-mini", original: sampling)
        XCTAssertEqual(adjusted.temperature, 0.3)
        XCTAssertEqual(adjusted.topP, 1.0)
        XCTAssertEqual(adjusted.frequencyPenalty, 0.0)
        XCTAssertEqual(adjusted.presencePenalty, 0.0)
    }

    func testUnsupportedParamNameFromErrorMessages() {
        let parameterMessage = "Unsupported parameter: 'temperature' is not supported with this model. (HTTP 400, invalid_request_body, request id 00000)"
        XCTAssertEqual(OpenAIClient.unsupportedParamName(in: parameterMessage), "temperature")
        let valueMessage = "Unsupported value: 'top_p' does not support 0.9 with this model. Only the default (1) value is supported."
        XCTAssertEqual(OpenAIClient.unsupportedParamName(in: valueMessage), "top_p")
        XCTAssertEqual(
            OpenAIClient.unsupportedParamName(in: "Unrecognized request argument supplied: frequency_penalty"),
            "frequency_penalty"
        )
        XCTAssertNil(OpenAIClient.unsupportedParamName(in: "Invalid API key provided."))
    }

    func testParamsDroppingRemovesNamedParamOnly() {
        let dropped = OpenAIClient.paramsDropping("temperature", from: sampling)
        XCTAssertNotNil(dropped)
        XCTAssertNil(dropped?.temperature)
        XCTAssertEqual(dropped?.topP, 1.0)
        XCTAssertEqual(dropped?.frequencyPenalty, 0.0)

        XCTAssertNil(OpenAIClient.paramsDropping("max_tokens", from: sampling))
        XCTAssertNil(
            OpenAIClient.paramsDropping(
                "temperature",
                from: AITaskParameters(
                    temperature: nil, topP: nil, frequencyPenalty: nil, presencePenalty: nil, reasoningEffort: nil, textVerbosity: nil
                )
            )
        )
    }
}

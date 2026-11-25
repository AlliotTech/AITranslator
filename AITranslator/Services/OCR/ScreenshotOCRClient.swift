import AppKit
import Foundation

/// OpenAI 兼容的视觉（OCR）客户端：非流式 chat/completions，
/// 发送 base64 图片并取回识别文本。
///
/// 独立于 `OpenAIClient`（流式、纯文本）：OCR 只需要一次性完整结果，
/// 不为多模态改动现有流式协议。
struct ScreenshotOCRClient {
    /// OCR 系统提示：只输出图中文字，保留原始换行，不做翻译或解释
    static let systemPrompt =
        "You are an OCR engine. Extract all text from the image exactly as it appears."
        + " Reply with only the recognized text, preserving line breaks and reading order,"
        + " without any explanations, notes, or translation."
}

private struct OCRContentPart: Encodable {
    let type: String

    var text: String?
    var imageURL: ImageURL?

    struct ImageURL: Encodable {
        let url: String
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
    }

    static func text(_ value: String) -> OCRContentPart {
        OCRContentPart(type: "text", text: value, imageURL: nil)
    }

    static func imageURL(_ dataURI: String) -> OCRContentPart {
        OCRContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: dataURI))
    }
}

private struct OCRRequestBody: Encodable {
    struct Message: Encodable {
        let role: String
        let content: [OCRContentPart]
    }

    let model: String
    let messages: [Message]
}

private struct OCRResponseBody: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message?
    }
    let choices: [Choice]?
}

extension ScreenshotOCRClient {
    enum OCRError: LocalizedError {
        case emptyResponse
        case http(status: Int, message: String)
        case imageEncodingFailed

        var errorDescription: String? {
            switch self {
            case .emptyResponse:
                return "OCR returned no text."
            case let .http(status, message):
                return "HTTP \(status): \(message)"
            case .imageEncodingFailed:
                return "Failed to encode screenshot to PNG."
            }
        }
    }

    func recognize(
        imageData: Data,
        mimeType: String,
        baseURL: String,
        apiKey: String,
        model: String,
        proxy: HTTPClient.ProxySettings?,
        userAgent: String?
    ) async throws -> String {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let userAgent, !userAgent.isEmpty {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        request.timeoutInterval = 120

        let dataURI = "data:\(mimeType);base64,\(imageData.base64EncodedString())"
        let body = OCRRequestBody(
            model: model,
            messages: [
                .init(role: "system", content: [.text(Self.systemPrompt)]),
                .init(role: "user", content: [
                    .text("Extract all text from this image."),
                    .imageURL(dataURI),
                ]),
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await HTTPClient.data(for: request, proxy: proxy)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw OCRError.http(status: http.statusCode, message: Self.errorMessage(from: data, status: http.statusCode))
        }

        let decoded = try JSONDecoder().decode(OCRResponseBody.self, from: data)
        guard let text = decoded.choices?.first?.message?.content,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.emptyResponse
        }
        return text
    }

    private static func errorMessage(from data: Data, status: Int) -> String {
        struct Envelope: Decodable {
            struct Inner: Decodable { let message: String? }
            let error: Inner?
        }
        if let obj = try? JSONDecoder().decode(Envelope.self, from: data),
            let msg = obj.error?.message, !msg.isEmpty {
            return msg
        }
        if let text = String(data: data, encoding: .utf8),
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(text.prefix(300))
        }
        return "request failed"
    }
}

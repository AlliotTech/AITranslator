import Foundation

private struct ChatChunk: Decodable { let choices: [Choice] }
private struct Choice: Decodable { let delta: Delta?; let message: Message? }
private struct Delta: Decodable { let content: String? }
private struct Message: Decodable { let content: String? }

enum SSEParser {
    /// 复用 JSONDecoder 实例，避免每次解析都创建新实例
    private static let decoder = JSONDecoder()

    static func parseDelta(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8) else { return nil }
        if let chunk = try? decoder.decode(ChatChunk.self, from: data) {
            if let content = chunk.choices.first?.delta?.content { return content }
            if let content = chunk.choices.first?.message?.content { return content }
        }
        return nil
    }
}

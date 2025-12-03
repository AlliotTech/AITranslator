import Foundation
import Combine

enum AppMode: String, CaseIterable, Identifiable, Codable {
    case translate
    case polish
    case summarize
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .translate: return "翻译"
        case .polish: return "润色"
        case .summarize: return "总结"
        }
    }
}

final class SessionState: ObservableObject, Codable {
    @Published var mode: AppMode
    @Published var sourceLang: String
    @Published var targetLang: String

    @Published var input: String
    @Published var output: String
    @Published var isStreaming: Bool
    @Published var error: String?

    private enum CodingKeys: CodingKey {
        case mode, sourceLang, targetLang, input, output, isStreaming, error
    }

    init(
        mode: AppMode = .translate,
        sourceLang: String = "en",
        targetLang: String = "zh-CN",
        input: String = "",
        output: String = "",
        isStreaming: Bool = false,
        error: String? = nil
    ) {
        self.mode = mode
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.input = input
        self.output = output
        self.isStreaming = isStreaming
        self.error = error
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(AppMode.self, forKey: .mode)
        sourceLang = try container.decode(String.self, forKey: .sourceLang)
        targetLang = try container.decode(String.self, forKey: .targetLang)
        input = try container.decode(String.self, forKey: .input)
        output = try container.decode(String.self, forKey: .output)
        isStreaming = try container.decode(Bool.self, forKey: .isStreaming)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(sourceLang, forKey: .sourceLang)
        try container.encode(targetLang, forKey: .targetLang)
        try container.encode(input, forKey: .input)
        try container.encode(output, forKey: .output)
        try container.encode(isStreaming, forKey: .isStreaming)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

import Foundation

enum HistoryProvider: String, Codable, Equatable, Hashable {
    case openAICompatible
    case deepLCompatible
}

/// 历史记录数据模型
/// 记录每次翻译/润色/总结操作的完整信息
struct HistoryRecord: Identifiable, Codable, Equatable, Hashable {
    /// 唯一标识符
    let id: UUID

    /// 记录时间
    let timestamp: Date

    /// 操作模式（翻译/润色/总结）
    let mode: AppMode

    /// 源语言代码
    let sourceLang: String

    /// 目标语言代码
    let targetLang: String

    /// 输入文本
    let input: String

    /// 输出文本
    let output: String

    /// 执行请求的服务类型
    let provider: HistoryProvider

    /// 具体模型或服务配置
    let service: String

    /// 兼容旧界面和旧导出文件中的 model 语义
    var model: String { service }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, mode, sourceLang, targetLang, input, output
        case provider, service, model
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        mode: AppMode,
        sourceLang: String,
        targetLang: String,
        input: String,
        output: String,
        provider: HistoryProvider,
        service: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mode = mode
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.input = input
        self.output = output
        self.provider = provider
        self.service = service
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        mode = try container.decode(AppMode.self, forKey: .mode)
        sourceLang = try container.decode(String.self, forKey: .sourceLang)
        targetLang = try container.decode(String.self, forKey: .targetLang)
        input = try container.decode(String.self, forKey: .input)
        output = try container.decode(String.self, forKey: .output)

        if let decodedProvider = try container.decodeIfPresent(HistoryProvider.self, forKey: .provider) {
            provider = decodedProvider
            service = try container.decodeIfPresent(String.self, forKey: .service) ?? ""
        } else {
            provider = .openAICompatible
            service = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(mode, forKey: .mode)
        try container.encode(sourceLang, forKey: .sourceLang)
        try container.encode(targetLang, forKey: .targetLang)
        try container.encode(input, forKey: .input)
        try container.encode(output, forKey: .output)
        try container.encode(provider, forKey: .provider)
        try container.encode(service, forKey: .service)
    }

    // MARK: - Computed Properties

    /// 格式化的时间戳字符串
    /// 根据距离当前时间的长短使用不同格式
    func formattedTimestamp(locale: Locale = .current) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(timestamp) {
            // 今天: "下午 3:25"
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            // 昨天: "昨天 下午 3:25"
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            let timeStr = formatter.string(from: timestamp)
            let isZh = locale.language.languageCode?.identifier == "zh"
            return isZh ? "昨天 \(timeStr)" : "Yesterday \(timeStr)"
        } else if calendar.isDate(timestamp, equalTo: now, toGranularity: .weekOfYear) {
            // 本周: "周三 下午 3:25"
            let formatter = DateFormatter()
            formatter.locale = locale
            let isZh = locale.language.languageCode?.identifier == "zh"
            formatter.dateFormat = isZh ? "EEEE HH:mm" : "EEEE h:mm a"
            return formatter.string(from: timestamp)
        } else {
            // 更早: "2025-11-15 15:25"
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }

    /// 用于搜索的预览文本（截取前50个字符）
    var previewText: String {
        let inputPreview = String(input.prefix(50))
        let outputPreview = String(output.prefix(50))
        return "\(inputPreview) → \(outputPreview)"
    }

    /// 输入文本的预览（用于列表显示）
    var inputPreview: String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(100))
    }

    /// 输出文本的预览（用于列表显示）
    var outputPreview: String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(100))
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

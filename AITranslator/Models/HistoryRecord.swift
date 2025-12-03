import Foundation

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

    /// 使用的AI模型
    let model: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        mode: AppMode,
        sourceLang: String,
        targetLang: String,
        input: String,
        output: String,
        model: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mode = mode
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.input = input
        self.output = output
        self.model = model
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

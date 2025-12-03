import Foundation
import Combine

/// 历史记录管理器
/// 负责历史记录的业务逻辑：增删查改、搜索筛选
@MainActor
final class HistoryManager: ObservableObject {
    /// 所有历史记录（按时间降序排序）
    @Published var records: [HistoryRecord] = []

    /// 最大记录数限制
    /// - 0: 不记录
    /// - -1: 无限制
    /// - 正数: 限制最大记录数
    @Published var maxRecords: Int = 200

    private let store: HistoryPersisting

    /// 初始化历史记录管理器
    /// - Parameter store: 持久化存储实现（支持依赖注入，便于测试）
    init(store: HistoryPersisting = HistoryStore()) {
        self.store = store
        self.records = store.load()
    }

    // MARK: - CRUD Operations

    /// 添加新的历史记录
    /// - 自动去重：如果输入输出完全相同且时间在1分钟内，不重复记录
    /// - 自动限制记录数量
    func addRecord(
        mode: AppMode,
        sourceLang: String,
        targetLang: String,
        input: String,
        output: String,
        model: String
    ) {
        // maxRecords == 0 时不记录
        guard maxRecords != 0 else { return }

        // 去重检查：避免短时间内重复记录相同内容
        if let lastRecord = records.first,
           lastRecord.input == input,
           lastRecord.output == output,
           lastRecord.mode == mode,
           Date().timeIntervalSince(lastRecord.timestamp) < 60 {
            return
        }

        // 创建新记录
        let record = HistoryRecord(
            mode: mode,
            sourceLang: sourceLang,
            targetLang: targetLang,
            input: input,
            output: output,
            model: model
        )

        // 插入到最前面（最新的记录）
        records.insert(record, at: 0)

        // 限制记录数量（-1 表示无限制）
        if maxRecords > 0 && records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        // 持久化
        store.save(records)
    }

    /// 删除单条记录
    /// - Parameter id: 记录的唯一标识符
    func deleteRecord(id: UUID) {
        records.removeAll { $0.id == id }
        store.save(records)
    }

    /// 删除多条记录
    /// - Parameter ids: 要删除的记录ID列表
    func deleteRecords(ids: Set<UUID>) {
        records.removeAll { ids.contains($0.id) }
        store.save(records)
    }

    /// 清空所有历史记录
    func clearAll() {
        records.removeAll()
        store.clear()
    }

    // MARK: - Search & Filter

    /// 搜索历史记录（不改变原始数据，返回过滤结果）
    /// 搜索范围：输入文本、输出文本、模式名称、模型名称
    /// - Parameter query: 搜索关键词
    /// - Returns: 匹配的历史记录列表
    func search(query: String) -> [HistoryRecord] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return records }

        let lowercased = trimmedQuery.lowercased()
        return records.filter { record in
            record.input.lowercased().contains(lowercased) ||
            record.output.lowercased().contains(lowercased) ||
            record.mode.displayName.lowercased().contains(lowercased) ||
            record.model.lowercased().contains(lowercased)
        }
    }

    /// 按模式筛选历史记录
    /// - Parameter mode: 要筛选的模式（nil 表示不筛选）
    /// - Returns: 筛选后的历史记录列表
    func filter(by mode: AppMode?) -> [HistoryRecord] {
        guard let mode = mode else { return records }
        return records.filter { $0.mode == mode }
    }

    /// 按日期范围筛选历史记录
    /// - Parameters:
    ///   - startDate: 开始日期（包含，nil 表示不限制）
    ///   - endDate: 结束日期（包含，nil 表示不限制）
    /// - Returns: 筛选后的历史记录列表
    func filter(from startDate: Date?, to endDate: Date?) -> [HistoryRecord] {
        var filtered = records

        if let start = startDate {
            filtered = filtered.filter { $0.timestamp >= start }
        }

        if let end = endDate {
            // 结束日期包含当天的23:59:59
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            filtered = filtered.filter { $0.timestamp <= endOfDay }
        }

        return filtered
    }

    /// 组合搜索和筛选
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - mode: 模式筛选
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 筛选后的历史记录列表
    func searchAndFilter(
        query: String,
        mode: AppMode? = nil,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) -> [HistoryRecord] {
        var results = records

        // 应用模式筛选
        if let mode = mode {
            results = results.filter { $0.mode == mode }
        }

        // 应用日期范围筛选
        if let start = startDate {
            results = results.filter { $0.timestamp >= start }
        }
        if let end = endDate {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            results = results.filter { $0.timestamp <= endOfDay }
        }

        // 应用搜索关键词
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let lowercased = trimmedQuery.lowercased()
            results = results.filter { record in
                record.input.lowercased().contains(lowercased) ||
                record.output.lowercased().contains(lowercased) ||
                record.mode.displayName.lowercased().contains(lowercased) ||
                record.model.lowercased().contains(lowercased)
            }
        }

        return results
    }

    // MARK: - Grouping

    /// 按日期分组历史记录
    /// 分组规则：今天、昨天、本周、本月、更早（按月份）
    /// - Parameters:
    ///   - records: 要分组的记录列表
    ///   - appLanguage: 应用语言（用于多语言支持）
    /// - Returns: 分组后的记录（组名 + 记录列表）
    func groupByDate(_ records: [HistoryRecord], appLanguage: AppLanguage) -> [(String, [HistoryRecord])] {
        let calendar = Calendar.current
        let now = Date()
        let locale = Locale(identifier: appLanguage.localeIdentifier ?? "en")

        var groups: [String: [HistoryRecord]] = [:]

        // 本地化的日期组标签
        let todayLabel = L10n.tr("history.date.today", lang: appLanguage)
        let yesterdayLabel = L10n.tr("history.date.yesterday", lang: appLanguage)
        let thisWeekLabel = L10n.tr("history.date.thisWeek", lang: appLanguage)
        let thisMonthLabel = L10n.tr("history.date.thisMonth", lang: appLanguage)

        // 按组归类
        for record in records {
            let key: String
            if calendar.isDateInToday(record.timestamp) {
                key = todayLabel
            } else if calendar.isDateInYesterday(record.timestamp) {
                key = yesterdayLabel
            } else if calendar.isDate(record.timestamp, equalTo: now, toGranularity: .weekOfYear) {
                key = thisWeekLabel
            } else if calendar.isDate(record.timestamp, equalTo: now, toGranularity: .month) {
                key = thisMonthLabel
            } else {
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.dateFormat = appLanguage == .zhHans ? "yyyy年M月" : "MMMM yyyy"
                key = formatter.string(from: record.timestamp)
            }

            groups[key, default: []].append(record)
        }

        // 排序分组（按优先级）
        let order = [todayLabel, yesterdayLabel, thisWeekLabel, thisMonthLabel]

        return groups.sorted { a, b in
            if let aIdx = order.firstIndex(of: a.key),
               let bIdx = order.firstIndex(of: b.key) {
                return aIdx < bIdx
            }
            // 其他组按时间倒序（通过第一条记录的时间比较）
            let aTime = a.value.first?.timestamp ?? Date.distantPast
            let bTime = b.value.first?.timestamp ?? Date.distantPast
            return aTime > bTime
        }
    }

    // MARK: - Import/Export

    /// 导出历史记录到 JSON 文件
    /// - Parameter url: 导出文件的目标路径
    /// - Throws: 文件操作错误
    func exportToJSON(url: URL) throws {
        try store.exportToURL(url, records: records)
    }

    /// 从 JSON 文件导入历史记录
    /// - Parameters:
    ///   - url: 导入文件的路径
    ///   - merge: 是否合并到现有记录（true=合并，false=替换）
    /// - Throws: 文件读取或解析错误
    func importFromJSON(url: URL, merge: Bool = true) throws {
        let importedRecords = try store.importFromURL(url)

        if merge {
            // 合并：去重后添加到现有记录
            let existingIDs = Set(records.map { $0.id })
            let newRecords = importedRecords.filter { !existingIDs.contains($0.id) }
            records.append(contentsOf: newRecords)

            // 重新排序
            records.sort { $0.timestamp > $1.timestamp }

            // 应用数量限制
            if maxRecords > 0 && records.count > maxRecords {
                records = Array(records.prefix(maxRecords))
            }
        } else {
            // 替换：直接使用导入的记录
            records = importedRecords.sorted { $0.timestamp > $1.timestamp }
        }

        store.save(records)
    }

    // MARK: - Statistics

    /// 获取历史记录统计信息
    func getStatistics() -> HistoryStatistics {
        HistoryStatistics(
            totalCount: records.count,
            translateCount: records.filter { $0.mode == .translate }.count,
            polishCount: records.filter { $0.mode == .polish }.count,
            summarizeCount: records.filter { $0.mode == .summarize }.count,
            storageSize: store.getStorageSize()
        )
    }
}

// MARK: - Supporting Types

/// 历史记录统计信息
struct HistoryStatistics {
    let totalCount: Int
    let translateCount: Int
    let polishCount: Int
    let summarizeCount: Int
    let storageSize: Int64

    /// 格式化的存储大小字符串
    var formattedStorageSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: storageSize)
    }
}

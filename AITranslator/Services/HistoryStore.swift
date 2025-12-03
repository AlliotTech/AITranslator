import Foundation

/// 历史记录持久化协议
protocol HistoryPersisting {
    /// 加载所有历史记录
    func load() -> [HistoryRecord]

    /// 保存历史记录列表
    func save(_ records: [HistoryRecord])

    /// 清空所有历史记录
    func clear()

    /// 获取历史记录文件大小（字节）
    func getStorageSize() -> Int64

    /// 导出历史记录到指定 URL
    func exportToURL(_ url: URL, records: [HistoryRecord]) throws

    /// 从指定 URL 导入历史记录
    func importFromURL(_ url: URL) throws -> [HistoryRecord]
}

/// 历史记录持久化实现
/// 使用 JSON 文件存储在 Application Support 目录
final class HistoryStore: HistoryPersisting {
    private let fileURL: URL
    private nonisolated(unsafe) let fileManager = FileManager.default

    /// 初始化历史记录存储
    /// 文件路径: ~/Library/Application Support/AITranslator/history.json
    nonisolated init() {
        // 获取 Application Support 目录
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        // 创建应用专属目录
        let appDir = appSupport.appendingPathComponent("AITranslator", isDirectory: true)

        // 确保目录存在
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.fileURL = appDir.appendingPathComponent("history.json")
    }

    /// 加载历史记录（按时间降序排序）
    func load() -> [HistoryRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)

            // 处理空文件情况
            guard !data.isEmpty else {
                return []
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let records = try decoder.decode([HistoryRecord].self, from: data)

            // 按时间降序排序（最新的在前面）
            return records.sorted { $0.timestamp > $1.timestamp }
        } catch {
            // 解析失败时记录错误并返回空数组（避免损坏的数据影响应用启动）
            print("❌ Failed to load history: \(error)")

            // 备份损坏的文件
            backupCorruptedFile()

            return []
        }
    }

    /// 保存历史记录
    func save(_ records: [HistoryRecord]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Failed to save history: \(error)")
        }
    }

    /// 清空所有历史记录
    func clear() {
        do {
            // 如果文件存在，删除它
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("❌ Failed to clear history: \(error)")
        }
    }

    /// 获取历史记录文件大小（字节）
    func getStorageSize() -> Int64 {
        guard fileManager.fileExists(atPath: fileURL.path),
              let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }

    // MARK: - Import/Export

    /// 导出历史记录到指定 URL
    /// - Parameter url: 导出文件的目标路径
    /// - Throws: 文件操作错误
    func exportToURL(_ url: URL, records: [HistoryRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(records)

        // 清理转义的斜杠（美化 JSON）
        if var jsonString = String(data: data, encoding: .utf8) {
            jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
            if let cleanedData = jsonString.data(using: .utf8) {
                try cleanedData.write(to: url, options: .atomic)
                return
            }
        }

        // 如果清理失败，直接写入原始数据
        try data.write(to: url, options: .atomic)
    }

    /// 从指定 URL 导入历史记录
    /// - Parameter url: 导入文件的路径
    /// - Returns: 导入的历史记录列表
    /// - Throws: 文件读取或解析错误
    func importFromURL(_ url: URL) throws -> [HistoryRecord] {
        let data = try Data(contentsOf: url)

        guard !data.isEmpty else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try decoder.decode([HistoryRecord].self, from: data)

        return records
    }

    // MARK: - Private Methods

    /// 备份损坏的历史记录文件
    private func backupCorruptedFile() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        let timestamp = Int(Date().timeIntervalSince1970)
        let backupURL = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupted.\(timestamp).json")

        try? fileManager.copyItem(at: fileURL, to: backupURL)
        try? fileManager.removeItem(at: fileURL)

        print("📦 Corrupted history file backed up to: \(backupURL.path)")
    }
}

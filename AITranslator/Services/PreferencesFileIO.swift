import AppKit
import UniformTypeIdentifiers

/// 偏好设置的 JSON 导入导出（含系统面板）
///
/// 只负责面板与文件读写，不产出界面文案；失败以错误抛出，由调用方映射为提示。
@MainActor
enum PreferencesFileIO {
    /// 导出到用户选择的位置；返回 false 表示用户取消
    @discardableResult
    static func export(_ preferences: Preferences) throws -> Bool {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "ai-translator-preferences.json"
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.json]
        } else {
            panel.allowedFileTypes = ["json"]
        }
        panel.isExtensionHidden = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preferences)
        if var jsonString = String(data: data, encoding: .utf8) {
            jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
            if let cleanedData = jsonString.data(using: .utf8) {
                try cleanedData.write(to: url, options: .atomic)
            } else {
                try data.write(to: url, options: .atomic)
            }
        } else {
            try data.write(to: url, options: .atomic)
        }
        return true
    }

    /// 从用户选择的文件导入；返回 nil 表示用户取消
    static func importPreferences() throws -> Preferences? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.json]
        } else {
            panel.allowedFileTypes = ["json"]
        }

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        // 不自动应用；由调用方决定何时写入草稿并保存
        return decoded
    }
}

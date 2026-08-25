import AppKit

/// 系统剪贴板写入
@MainActor
enum Clipboard {
    /// 写入纯文本（覆盖现有内容）
    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

import Foundation

/// 翻译提供方向 ViewModel 输出的统一事件
///
/// 所有提供方（流式 / 分块）都只通过该事件序列表达进展，
/// ViewModel 不需要知道具体是哪个提供方。
enum TranslationEvent: Equatable, Sendable {
    /// 追加一段输出文本
    case delta(String)

    /// 将输出整体替换为该文本（续传时恢复已完成部分）
    case reset(String)

    /// 分块任务进度；不分块的提供方不会发送该事件
    case progress(completed: Int, total: Int)
}

/// 续传句柄
///
/// 由提供方生成、由提供方校验并消费；ViewModel 只负责保存与回传，
/// 不感知其内部结构（例如 DeepL 的分块与已完成文本）。
protocol TranslationResumeToken {}

/// 提供方失败信息
///
/// `resumeToken` 非空表示该次失败可以从中断处继续。
struct TranslationFailure: LocalizedError {
    let message: String
    let resumeToken: (any TranslationResumeToken)?

    init(message: String, resumeToken: (any TranslationResumeToken)? = nil) {
        self.message = message
        self.resumeToken = resumeToken
    }

    var errorDescription: String? { message }
}

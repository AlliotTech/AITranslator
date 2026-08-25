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

/// 提供方失败原因
///
/// 服务层只描述“发生了什么”，不产出界面文案；文案由 UI 层（AppViewModel）映射，
/// 这样服务层不依赖本地化与当前界面语言。
enum TranslationFailureReason: Equatable, Sendable {
    /// 当前 DeepL 配置不支持润色（需要 Pro 或声明支持 Write 的 /v2 服务）
    case polishUnavailable

    /// 当前提供方不支持总结
    case summarizeUnavailable

    /// 分块任务失败：`chunkNumber` 为 1 起的块序号
    case chunkFailure(chunkNumber: Int, total: Int, underlying: String)

    /// 底层错误（网络 / 协议），描述已由底层给出
    case underlying(String)
}

/// 提供方失败信息
///
/// `resumeToken` 非空表示该次失败可以从中断处继续。
struct TranslationFailure: Error {
    let reason: TranslationFailureReason
    let resumeToken: (any TranslationResumeToken)?

    init(reason: TranslationFailureReason, resumeToken: (any TranslationResumeToken)? = nil) {
        self.reason = reason
        self.resumeToken = resumeToken
    }
}

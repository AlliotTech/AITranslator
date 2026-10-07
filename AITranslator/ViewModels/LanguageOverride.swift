import Foundation

/// 语言覆盖状态管理
/// 统一管理用户手动指定语言的状态，避免使用多个分散的布尔标志
struct LanguageOverrideState {
    /// 用户是否手动指定了源语言
    var source = false

    /// 用户是否手动指定了目标语言
    var target = false

    /// 在 Summarize 模式下用户是否手动指定了目标语言
    /// (Summarize 模式有特殊逻辑，目标语言默认跟随源语言)
    var targetInSummarize = false

    /// 重置所有覆盖状态（例如清空输入时）
    mutating func reset() {
        source = false
        target = false
        targetInSummarize = false
    }

    /// 重置源语言覆盖状态
    mutating func resetSource() {
        source = false
    }

    /// 重置目标语言覆盖状态
    mutating func resetTarget() {
        target = false
        targetInSummarize = false
    }
}

/// 记忆的目标语言
/// 用于模式切换时恢复每个模式之前使用的目标语言
struct RememberedTargetLanguages {
    /// 翻译模式下最后使用的目标语言
    var translate: String?

    /// 总结模式下最后使用的目标语言
    var summarize: String?

    /// 获取指定模式的记忆语言
    func get(for mode: AppMode) -> String? {
        switch mode {
        case .translate:
            return translate
        case .summarize:
            return summarize
        case .polish:
            return nil  // Polish 模式目标语言总是等于源语言
        }
    }

    /// 设置指定模式的记忆语言
    mutating func set(_ language: String, for mode: AppMode) {
        switch mode {
        case .translate:
            translate = language
        case .summarize:
            summarize = language
        case .polish:
            break  // Polish 模式不需要记忆
        }
    }
}

/// 语言变更类型
enum LanguageChangeType {
    case source  // 源语言变更
    case target  // 目标语言变更
}

/// 语言变更后是否自动触发任务的决策表
enum AutoSendPolicy {
    /// 判断语言变更后是否应该自动触发翻译/润色/总结
    /// - Parameters:
    ///   - mode: 当前模式
    ///   - hasInput: 输入框是否非空
    ///   - changeType: 语言变更类型
    static func shouldAutoSend(mode: AppMode, hasInput: Bool, changeType: LanguageChangeType) -> Bool {
        // 检查是否有输入内容
        guard hasInput else { return false }

        switch (mode, changeType) {
        case (.translate, .source), (.translate, .target):
            // 翻译模式：改变源语言或目标语言都自动触发
            return true
        case (.polish, .source):
            // 润色模式：改变源语言自动触发（目标语言会自动跟随源语言）
            return true
        case (.polish, .target):
            // 润色模式：目标语言由源语言决定，不需要单独触发
            return false
        case (.summarize, .source), (.summarize, .target):
            // 总结模式：改变源语言或目标语言都自动触发
            return true
        }
    }
}

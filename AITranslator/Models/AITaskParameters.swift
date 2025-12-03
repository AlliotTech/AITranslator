import Foundation

/// AI任务参数配置
/// 根据不同场景（翻译、润色、总结等）提供优化的OpenAI参数
struct AITaskParameters {
    let temperature: Double?
    let topP: Double?
    let frequencyPenalty: Double?
    let presencePenalty: Double?
    let reasoningEffort: String?
    let textVerbosity: String?

    /// 根据应用模式获取最优参数配置
    static func parameters(for mode: AppMode) -> AITaskParameters {
        switch mode {
        case .translate:
            // 翻译：强调准确性和术语一致性
            // - 低temperature保证翻译稳定
            // - 不使用惩罚，允许术语重复
            return AITaskParameters(
                temperature: 0.3,
                topP: 1.0,
                frequencyPenalty: 0.0,
                presencePenalty: 0.0,
                reasoningEffort: nil,
                textVerbosity: nil
            )

        case .polish:
            // 润色：平衡准确性与表达多样性
            // - 中等temperature允许一定创造性
            // - 适度frequency_penalty避免用词单调
            // - 轻微presence_penalty鼓励表达多样化
            return AITaskParameters(
                temperature: 0.5,
                topP: 0.95,
                frequencyPenalty: 0.3,
                presencePenalty: 0.1,
                reasoningEffort: nil,
                textVerbosity: nil
            )

        case .summarize:
            // 总结：强调信息提取准确性
            // - 低temperature保证总结稳定
            // - 不使用惩罚，保留关键概念和术语
            return AITaskParameters(
                temperature: 0.2,
                topP: 1.0,
                frequencyPenalty: 0.0,
                presencePenalty: 0.0,
                reasoningEffort: nil,
                textVerbosity: nil
            )
        }
    }

    /// 获取默认参数（用于向后兼容）
    static var `default`: AITaskParameters {
        return AITaskParameters(
            temperature: 0.3,
            topP: 1.0,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0,
            reasoningEffort: nil,
            textVerbosity: nil
        )
    }
}

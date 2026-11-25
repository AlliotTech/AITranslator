import Foundation

/// 模型约束配置
/// 用于处理特定模型的特殊参数要求
struct ModelConstraints {
    /// 根据模型调整参数
    ///
    /// 推理类模型（o1/o3/o4、gpt-5 系列）不支持采样参数：官方文档要求
    /// 完全省略 temperature/top_p/penalties 字段，而不是发送默认值
    /// （GitHub Copilot 等兼容网关会对出现的字段直接返回
    /// "Unsupported parameter: 'temperature' is not supported with this model"）。
    static func adjustParameters(model: String, original: AITaskParameters) -> AITaskParameters {
        let name = model.split(separator: "/").last.map(String.init)?.lowercased() ?? model.lowercased()

        let isReasoningModel =
            name.hasPrefix("o1") || name.hasPrefix("o3") || name.hasPrefix("o4")
            || name.hasPrefix("gpt-5")
        if isReasoningModel {
            return AITaskParameters(
                temperature: nil,
                topP: nil,
                frequencyPenalty: nil,
                presencePenalty: nil,
                reasoningEffort: "minimal",
                textVerbosity: "low"
            )
        }

        return original
    }
}

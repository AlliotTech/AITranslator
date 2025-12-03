import Foundation

/// 模型约束配置  
/// 用于处理特定模型的特殊参数要求  
struct ModelConstraints {  
    /// 根据模型调整参数  
    static func adjustParameters(model: String, original: AITaskParameters) -> AITaskParameters {  
        
        let modelLower = model.lowercased()
        
        if modelLower.contains("gpt-5") &&
           !modelLower.contains("gpt-4") &&
           !modelLower.contains("gpt-3") {
            
            return AITaskParameters(
                temperature: 1.0,
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
import Foundation

/// 源语言检测
/// 包装语言检测与标准化，缓存最近一次检测结果，避免重复检测相同文本
@MainActor
final class SourceLanguageDetector {
    private var lastDetectedText: String?
    private var lastDetectedLang: String?

    /// 检测源语言并标准化（包含缓存逻辑）
    /// - Parameters:
    ///   - text: 待检测的文本
    ///   - engine: 检测引擎
    ///   - proxy: 代理配置
    /// - Returns: 标准化的语言代码
    func detect(
        for text: String,
        engine: DetectionEngine,
        proxy: HTTPClient.ProxySettings?
    ) async -> String {
        let limited = LanguageDetector.limitedText(text, for: engine)

        // 检查缓存
        if let cachedText = lastDetectedText,
           let cachedLang = lastDetectedLang,
           cachedText == limited {
            return LanguageUtils.standardize(code: cachedLang)
        }

        // 执行检测
        let result = await LanguageDetector.detect(text: limited, engine: engine, proxy: proxy)
        let standardized = LanguageUtils.standardize(code: result.languageCode)

        // 更新缓存
        lastDetectedText = limited
        lastDetectedLang = standardized

        return standardized
    }

    /// 清空检测缓存（例如清空输入后）
    func reset() {
        lastDetectedText = nil
        lastDetectedLang = nil
    }
}

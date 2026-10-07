import Foundation

extension TranslationFailureReason {
    /// 把结构化失败原因映射为当前界面语言的文案。
    /// 文案映射属于 UI 层职责（服务层不依赖本地化，见 TranslationFailureReason 的说明）。
    /// - Parameter appLanguage: 当前界面语言
    /// - Returns: 本地化的错误文案
    func localizedMessage(appLanguage: AppLanguage) -> String {
        switch self {
        case .polishUnavailable:
            return L10n.tr("error.deepL.writeUnavailable", lang: appLanguage)
        case .summarizeUnavailable:
            return L10n.tr("error.deepL.summarizeUnavailable", lang: appLanguage)
        case let .chunkFailure(chunkNumber, total, underlying):
            return String(
                format: L10n.tr("error.deepL.chunkFailure", lang: appLanguage),
                chunkNumber,
                total,
                underlying
            )
        case .underlying(let text):
            return text
        }
    }
}

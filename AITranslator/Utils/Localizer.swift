import SwiftUI

/// 视图层本地化入口
///
/// 把 `appLanguage` 从每个调用点收敛到 Environment：视图只需
/// `@Environment(\.l10n) private var l10n`，然后 `l10n("btn.send")`，
/// 不必再层层取 `viewModel.preferences.appLanguage`。
struct Localizer: Equatable {
    let language: AppLanguage

    /// 取本地化文案
    func callAsFunction(_ key: String) -> String {
        L10n.tr(key, lang: language)
    }

    /// 取带格式参数的本地化文案（对应 %d / %@ 等占位符）
    func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: L10n.tr(key, lang: language), arguments: arguments)
    }

    /// 语言选项的显示名（跟随当前界面语言）
    func languageDisplayName(_ option: AppLanguage) -> String {
        L10n.languageDisplayName(option, uiLang: language)
    }

    /// 模式名（翻译 / 润色 / 总结）
    func modeName(_ mode: AppMode) -> String {
        switch mode {
        case .translate:
            return self("mode.translate")
        case .polish:
            return self("mode.polish")
        case .summarize:
            return self("mode.summarize")
        }
    }
}

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue = Localizer(language: .system)
}

extension EnvironmentValues {
    var l10n: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}

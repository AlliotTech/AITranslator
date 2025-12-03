import SwiftUI

struct GeneralSettingsSection: View {
    @ObservedObject var draft: Preferences
    let viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("settings.general.title", lang: viewModel.preferences.appLanguage))
                .headlineStyle()
                .foregroundColor(.primary)
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text(L10n.tr("settings.general.appLanguage", lang: viewModel.preferences.appLanguage))
                    Picker("", selection: $draft.appLanguage) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(L10n.languageDisplayName(option, uiLang: viewModel.preferences.appLanguage)).tag(option)
                        }
                    }
                    .labelsHidden()
                    .help(L10n.tr("settings.general.appLanguage.help", lang: viewModel.preferences.appLanguage))
                }
                GridRow {
                    Text(L10n.tr("settings.general.detectionEngine", lang: viewModel.preferences.appLanguage))
                    Picker("", selection: $draft.detectionEngine) {
                        ForEach(DetectionEngine.allCases) { e in
                            switch e {
                            case .local:
                                Text(L10n.tr("detection.local", lang: viewModel.preferences.appLanguage)).tag(e)
                            case .google:
                                Text(L10n.tr("detection.google", lang: viewModel.preferences.appLanguage)).tag(e)
                            case .baidu:
                                Text(L10n.tr("detection.baidu", lang: viewModel.preferences.appLanguage)).tag(e)
                            case .bing:
                                Text(L10n.tr("detection.bing", lang: viewModel.preferences.appLanguage)).tag(e)
                            }
                        }
                    }
                    .labelsHidden()
                    .help(L10n.tr("settings.general.detectionEngine.help", lang: viewModel.preferences.appLanguage))
                }
                GridRow {
                    Text(L10n.tr("settings.general.defaultTargetLanguage", lang: viewModel.preferences.appLanguage))
                    Picker("", selection: $draft.defaultTargetLanguage) {
                        ForEach(LanguageUtils.supported) { lang in
                            Text(lang.name).tag(lang.id)
                        }
                    }
                    .labelsHidden()
                    .help(L10n.tr("settings.general.defaultTargetLanguage.help", lang: viewModel.preferences.appLanguage))
                }
                GridRow {
                    Text(L10n.tr("settings.general.historyMaxRecords", lang: viewModel.preferences.appLanguage))
                    Picker("", selection: $draft.historyMaxRecords) {
                        Text(L10n.tr("settings.history.disabled", lang: viewModel.preferences.appLanguage))
                            .tag(0)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                        Text(L10n.tr("settings.history.unlimited", lang: viewModel.preferences.appLanguage))
                            .tag(-1)
                    }
                    .labelsHidden()
                    .help(L10n.tr("settings.general.historyMaxRecords.help", lang: viewModel.preferences.appLanguage))
                }
            }
            Spacer(minLength: 0)
        }
    }
}

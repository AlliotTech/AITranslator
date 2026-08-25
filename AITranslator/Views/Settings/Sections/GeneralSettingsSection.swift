import SwiftUI

struct GeneralSettingsSection: View {
    @Binding var draft: Preferences
    let viewModel: AppViewModel
    @Environment(\.l10n)
    private var l10n

    var body: some View {
        SettingsPage(l10n("settings.general.title")) {
            SettingsFormGrid {
                GridRow {
                    fieldLabel("settings.general.appLanguage")
                    Picker("", selection: $draft.appLanguage) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(l10n.languageDisplayName(option)).tag(option)
                        }
                    }
                    .labelsHidden()
                    .settingsFieldControl()
                    .help(l10n("settings.general.appLanguage.help"))
                }

                GridRow {
                    fieldLabel("settings.general.detectionEngine")
                    Picker("", selection: $draft.detectionEngine) {
                        ForEach(DetectionEngine.allCases) { e in
                            switch e {
                            case .local:
                                Text(l10n("detection.local")).tag(e)
                            case .google:
                                Text(l10n("detection.google")).tag(e)
                            case .baidu:
                                Text(l10n("detection.baidu")).tag(e)
                            case .bing:
                                Text(l10n("detection.bing")).tag(e)
                            }
                        }
                    }
                    .labelsHidden()
                    .settingsFieldControl()
                    .help(l10n("settings.general.detectionEngine.help"))
                }

                GridRow {
                    fieldLabel("settings.general.defaultTargetLanguage")
                    Picker("", selection: $draft.defaultTargetLanguage) {
                        ForEach(LanguageUtils.supported) { lang in
                            Text(lang.name).tag(lang.id)
                        }
                    }
                    .labelsHidden()
                    .settingsFieldControl()
                    .help(l10n("settings.general.defaultTargetLanguage.help"))
                }

                GridRow {
                    fieldLabel("settings.general.historyMaxRecords")
                    Picker("", selection: $draft.historyMaxRecords) {
                        Text(l10n("settings.history.disabled"))
                            .tag(0)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                        Text(l10n("settings.history.unlimited"))
                            .tag(-1)
                    }
                    .labelsHidden()
                    .settingsFieldControl()
                    .help(l10n("settings.general.historyMaxRecords.help"))
                }
            }
        }
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(l10n(key))
            .settingsFieldLabel()
    }
}

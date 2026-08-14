import SwiftUI

struct HotkeysSettingsSection: View {
    @ObservedObject var draft: Preferences
    let viewModel: AppViewModel
    @Binding var sendKeyHelpPresented: Bool
    @Binding var showWindowHelpPresented: Bool
    @Binding var toggleModeHelpPresented: Bool
    @Binding var quickCopyHelpPresented: Bool

    var body: some View {
        SettingsPage(L10n.tr("settings.hotkeys.title", lang: viewModel.preferences.appLanguage)) {
            SettingsFormGrid {
                GridRow {
                    helpLabel(
                        "settings.hotkeys.sendKey",
                        helpKey: "settings.hotkeys.sendKey.help",
                        isPresented: $sendKeyHelpPresented
                    )
                    Picker("", selection: $draft.sendKey) {
                        Text(L10n.tr("settings.hotkeys.sendKey.enter", lang: viewModel.preferences.appLanguage)).tag(SendKey.enter)
                        Text(L10n.tr("settings.hotkeys.sendKey.cmdEnter", lang: viewModel.preferences.appLanguage)).tag(SendKey.cmdEnter)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .settingsFieldControl()
                }

                GridRow {
                    helpLabel(
                        "settings.hotkeys.showWindow",
                        helpKey: "settings.hotkeys.showWindow.help",
                        isPresented: $showWindowHelpPresented
                    )
                    HStack(spacing: 8) {
                        ShortcutRecorderField(value: $draft.shortcutShowWindow, placeholder: L10n.tr("settings.hotkeys.placeholder", lang: viewModel.preferences.appLanguage))
                            .frame(maxWidth: .infinity)
                        Button(L10n.tr("common.clear", lang: viewModel.preferences.appLanguage)) { draft.shortcutShowWindow = nil }
                            .buttonCursor()
                            .fixedSize()
                        Button(L10n.tr("common.restoreDefault", lang: viewModel.preferences.appLanguage)) { draft.shortcutShowWindow = HotkeyManager.Defaults.showHide }
                            .buttonCursor()
                            .fixedSize()
                    }
                    .settingsFieldControl()
                }

                GridRow {
                    helpLabel(
                        "settings.hotkeys.toggleMode",
                        helpKey: "settings.hotkeys.toggleMode.help",
                        isPresented: $toggleModeHelpPresented
                    )
                    HStack(spacing: 8) {
                        ShortcutRecorderField(value: $draft.shortcutToggleMode, placeholder: L10n.tr("settings.hotkeys.placeholder", lang: viewModel.preferences.appLanguage))
                            .frame(maxWidth: .infinity)
                        Button(L10n.tr("common.clear", lang: viewModel.preferences.appLanguage)) { draft.shortcutToggleMode = nil }
                            .buttonCursor()
                            .fixedSize()
                        Button(L10n.tr("common.restoreDefault", lang: viewModel.preferences.appLanguage)) { draft.shortcutToggleMode = HotkeyManager.Defaults.toggleMode }
                            .buttonCursor()
                            .fixedSize()
                    }
                    .settingsFieldControl()
                }

                GridRow {
                    helpLabel(
                        "settings.hotkeys.quickCopy",
                        helpKey: "settings.hotkeys.quickCopy.help",
                        isPresented: $quickCopyHelpPresented
                    )
                    HStack(spacing: 8) {
                        ShortcutRecorderField(value: $draft.shortcutQuickCopy, placeholder: L10n.tr("settings.hotkeys.placeholder", lang: viewModel.preferences.appLanguage))
                            .frame(maxWidth: .infinity)
                        Button(L10n.tr("common.clear", lang: viewModel.preferences.appLanguage)) { draft.shortcutQuickCopy = nil }
                            .buttonCursor()
                            .fixedSize()
                        Button(L10n.tr("common.restoreDefault", lang: viewModel.preferences.appLanguage)) { draft.shortcutQuickCopy = HotkeyManager.Defaults.quickCopy }
                            .buttonCursor()
                            .fixedSize()
                    }
                    .settingsFieldControl()
                }
            }
        }
    }

    private func helpLabel(_ titleKey: String, helpKey: String, isPresented: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Text(L10n.tr(titleKey, lang: viewModel.preferences.appLanguage))

            Spacer(minLength: 4)

            Button(action: { isPresented.wrappedValue.toggle() }) {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.plain)
            .buttonCursor()
            .popover(isPresented: isPresented) {
                Text(L10n.tr(helpKey, lang: viewModel.preferences.appLanguage))
                    .bodyStyle(comfortable: false)
                    .padding(12)
                    .frame(minWidth: 220)
            }
        }
        .settingsFieldLabel()
    }
}

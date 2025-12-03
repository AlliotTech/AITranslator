import SwiftUI

struct HotkeysSettingsSection: View {
    @ObservedObject var draft: Preferences
    let viewModel: AppViewModel
    @Binding var sendKeyHelpPresented: Bool
    @Binding var showWindowHelpPresented: Bool
    @Binding var toggleModeHelpPresented: Bool
    @Binding var quickCopyHelpPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("settings.hotkeys.title", lang: viewModel.preferences.appLanguage))
                .headlineStyle()
                .foregroundColor(.primary)
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    HStack(spacing: 6) {
                        Text(L10n.tr("settings.hotkeys.sendKey", lang: viewModel.preferences.appLanguage))
                        Spacer()
                        Button(action: { sendKeyHelpPresented.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .buttonCursor()
                        .popover(isPresented: $sendKeyHelpPresented) {
                            Text(L10n.tr("settings.hotkeys.sendKey.help", lang: viewModel.preferences.appLanguage))
                                .bodyStyle(comfortable: false)
                                .padding(12)
                                .frame(minWidth: 220)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("", selection: $draft.sendKey) {
                        Text(L10n.tr("settings.hotkeys.sendKey.enter", lang: viewModel.preferences.appLanguage)).tag(SendKey.enter)
                        Text(L10n.tr("settings.hotkeys.sendKey.cmdEnter", lang: viewModel.preferences.appLanguage)).tag(SendKey.cmdEnter)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                GridRow {
                    HStack(spacing: 6) {
                        Text(L10n.tr("settings.hotkeys.showWindow", lang: viewModel.preferences.appLanguage))
                        Spacer()
                        Button(action: { showWindowHelpPresented.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .buttonCursor()
                        .popover(isPresented: $showWindowHelpPresented) {
                            Text(L10n.tr("settings.hotkeys.showWindow.help", lang: viewModel.preferences.appLanguage))
                                .bodyStyle(comfortable: false)
                                .padding(12)
                                .frame(minWidth: 220)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        ShortcutRecorderField(value: $draft.shortcutShowWindow, placeholder: L10n.tr("settings.hotkeys.placeholder", lang: viewModel.preferences.appLanguage))
                        Button(L10n.tr("common.clear", lang: viewModel.preferences.appLanguage)) { draft.shortcutShowWindow = nil }
                            .buttonCursor()
                        Button(L10n.tr("common.restoreDefault", lang: viewModel.preferences.appLanguage)) { draft.shortcutShowWindow = HotkeyManager.Defaults.showHide }
                            .buttonCursor()
                    }
                }
                GridRow {
                    HStack(spacing: 6) {
                        Text(L10n.tr("settings.hotkeys.toggleMode", lang: viewModel.preferences.appLanguage))
                        Spacer()
                        Button(action: { toggleModeHelpPresented.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .buttonCursor()
                        .popover(isPresented: $toggleModeHelpPresented) {
                            Text(L10n.tr("settings.hotkeys.toggleMode.help", lang: viewModel.preferences.appLanguage))
                                .bodyStyle(comfortable: false)
                                .padding(12)
                                .frame(minWidth: 220)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        ShortcutRecorderField(value: $draft.shortcutToggleMode, placeholder: L10n.tr("settings.hotkeys.placeholder", lang: viewModel.preferences.appLanguage))
                        Button(L10n.tr("common.clear", lang: viewModel.preferences.appLanguage)) { draft.shortcutToggleMode = nil }
                            .buttonCursor()
                        Button(L10n.tr("common.restoreDefault", lang: viewModel.preferences.appLanguage)) { draft.shortcutToggleMode = HotkeyManager.Defaults.toggleMode }
                            .buttonCursor()
                    }
                }
                GridRow {
                    HStack(spacing: 6) {
                        Text(L10n.tr("settings.hotkeys.quickCopy", lang: viewModel.preferences.appLanguage))
                        Spacer()
                        Button(action: { quickCopyHelpPresented.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .buttonCursor()
                        .popover(isPresented: $quickCopyHelpPresented) {
                            Text(L10n.tr("settings.hotkeys.quickCopy.help", lang: viewModel.preferences.appLanguage))
                                .bodyStyle(comfortable: false)
                                .padding(12)
                                .frame(minWidth: 220)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        ShortcutRecorderField(value: $draft.shortcutQuickCopy, placeholder: L10n.tr("settings.hotkeys.placeholder", lang: viewModel.preferences.appLanguage))
                        Button(L10n.tr("common.clear", lang: viewModel.preferences.appLanguage)) { draft.shortcutQuickCopy = nil }
                            .buttonCursor()
                        Button(L10n.tr("common.restoreDefault", lang: viewModel.preferences.appLanguage)) { draft.shortcutQuickCopy = HotkeyManager.Defaults.quickCopy }
                            .buttonCursor()
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

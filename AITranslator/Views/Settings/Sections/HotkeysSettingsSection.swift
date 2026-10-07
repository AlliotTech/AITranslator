import SwiftUI

struct HotkeysSettingsSection: View {
    @Binding var draft: Preferences
    let viewModel: AppViewModel
    @Binding var sendKeyHelpPresented: Bool
    @Binding var showWindowHelpPresented: Bool
    @Binding var toggleModeHelpPresented: Bool
    @Binding var quickCopyHelpPresented: Bool
    @Environment(\.l10n)
    private var l10n

    var body: some View {
        SettingsPage(l10n("settings.hotkeys.title")) {
            SettingsFormGrid {
                GridRow {
                    helpLabel(
                        "settings.hotkeys.sendKey",
                        helpKey: "settings.hotkeys.sendKey.help",
                        isPresented: $sendKeyHelpPresented
                    )
                    Picker("", selection: $draft.sendKey) {
                        Text(l10n("settings.hotkeys.sendKey.enter")).tag(SendKey.enter)
                        Text(l10n("settings.hotkeys.sendKey.cmdEnter")).tag(SendKey.cmdEnter)
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
                        ShortcutRecorderField(value: $draft.shortcutShowWindow, placeholder: l10n("settings.hotkeys.placeholder"))
                            .frame(maxWidth: .infinity)
                        Button(l10n("common.clear")) { draft.shortcutShowWindow = nil }
                            .buttonCursor()
                            .fixedSize()
                        Button(l10n("common.restoreDefault")) { draft.shortcutShowWindow = HotkeyManager.Defaults.showHide }
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
                        ShortcutRecorderField(value: $draft.shortcutToggleMode, placeholder: l10n("settings.hotkeys.placeholder"))
                            .frame(maxWidth: .infinity)
                        Button(l10n("common.clear")) { draft.shortcutToggleMode = nil }
                            .buttonCursor()
                            .fixedSize()
                        Button(l10n("common.restoreDefault")) { draft.shortcutToggleMode = HotkeyManager.Defaults.toggleMode }
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
                        ShortcutRecorderField(value: $draft.shortcutQuickCopy, placeholder: l10n("settings.hotkeys.placeholder"))
                            .frame(maxWidth: .infinity)
                        Button(l10n("common.clear")) { draft.shortcutQuickCopy = nil }
                            .buttonCursor()
                            .fixedSize()
                        Button(l10n("common.restoreDefault")) { draft.shortcutQuickCopy = HotkeyManager.Defaults.quickCopy }
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
            Text(l10n(titleKey))

            Spacer(minLength: 4)

            Button {
                isPresented.wrappedValue.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.plain)
            .buttonCursor()
            .popover(isPresented: isPresented) {
                Text(l10n(helpKey))
                    .bodyStyle(comfortable: false)
                    .padding(12)
                    .frame(minWidth: 220)
            }
        }
        .settingsFieldLabel()
    }
}

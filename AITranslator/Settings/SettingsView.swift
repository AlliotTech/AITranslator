import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    @StateObject private var draft = Preferences()
    @State private var settingsWindowConfigured: Bool = false

    @State private var revealAPIKey: Bool = false
    @State private var proxyTestState: ProxyTestState = .idle
    @State private var saveCheckVisible: Bool = false
    @State private var resetConfirmPresented: Bool = false
    @State private var showWindowHelpPresented: Bool = false
    @State private var toggleModeHelpPresented: Bool = false
    @State private var quickCopyHelpPresented: Bool = false
    @State private var sendKeyHelpPresented: Bool = false

    enum ProxyTestState { case idle, testing, success, failure }

    private var hasChanges: Bool {
        let p = viewModel.preferences
        return draft.baseURL != p.baseURL
            || draft.model != p.model
            || draft.apiKey != p.apiKey
            || draft.appLanguage != p.appLanguage
            || draft.detectionEngine != p.detectionEngine
            || draft.defaultTargetLanguage != p.defaultTargetLanguage
            || draft.proxyType != p.proxyType
            || draft.proxyHost != p.proxyHost
            || draft.proxyPort != p.proxyPort
            || draft.proxyUsername != p.proxyUsername
            || draft.proxyPassword != p.proxyPassword
            || draft.noProxyTargets != p.noProxyTargets
            || draft.shortcutShowWindow != p.shortcutShowWindow
            || draft.shortcutToggleMode != p.shortcutToggleMode
            || draft.shortcutQuickCopy != p.shortcutQuickCopy
            || draft.sendKey != p.sendKey
            || draft.historyMaxRecords != p.historyMaxRecords
    }

    private var canSave: Bool { draft.isValid && hasChanges }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TabView {
                GeneralSettingsSection(draft: draft, viewModel: viewModel)
                    .controlSize(.small)
                    .frame(minHeight: 180, alignment: .top)
                    .tabItem { Label(L10n.tr("settings.tab.general", lang: viewModel.preferences.appLanguage), systemImage: "gearshape") }

                APISettingsSection(draft: draft, viewModel: viewModel, revealAPIKey: $revealAPIKey)
                    .controlSize(.small)
                    .frame(minHeight: 280, alignment: .top)
                    .tabItem { Label(L10n.tr("settings.tab.api", lang: viewModel.preferences.appLanguage), systemImage: "key") }

                ProxySettingsSection(draft: draft, viewModel: viewModel, proxyTestState: $proxyTestState)
                    .controlSize(.small)
                    .frame(minHeight: 280, alignment: .top)
                    .tabItem { Label(L10n.tr("settings.tab.proxy", lang: viewModel.preferences.appLanguage), systemImage: "globe") }

                HotkeysSettingsSection(
                    draft: draft,
                    viewModel: viewModel,
                    sendKeyHelpPresented: $sendKeyHelpPresented,
                    showWindowHelpPresented: $showWindowHelpPresented,
                    toggleModeHelpPresented: $toggleModeHelpPresented,
                    quickCopyHelpPresented: $quickCopyHelpPresented
                )
                .controlSize(.small)
                .frame(minHeight: 220, alignment: .top)
                .tabItem { Label(L10n.tr("settings.tab.hotkeys", lang: viewModel.preferences.appLanguage), systemImage: "keyboard") }
            }
            Text(L10n.tr("common.changesNotAutoSaved", lang: viewModel.preferences.appLanguage))
                .footnoteStyle()
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 0)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button(L10n.tr("common.resetDefaults", lang: viewModel.preferences.appLanguage)) {
                    resetConfirmPresented = true
                }
                .buttonCursor()
                Button(L10n.tr("common.import", lang: viewModel.preferences.appLanguage)) {
                    if let imported = viewModel.importPreferencesFromJSON() {
                        // Load into draft only; user must click Save to apply
                        draft.load(from: imported)
                    }
                }
                .buttonCursor()
                Button(L10n.tr("common.export", lang: viewModel.preferences.appLanguage)) {
                    viewModel.exportPreferencesToJSON()
                }
                .buttonCursor()
                Spacer()
                Button(action: {
                    let newPrefs = Preferences(
                        appLanguage: draft.appLanguage,
                        baseURL: draft.baseURL,
                        model: draft.model,
                        apiKey: draft.apiKey,
                        detectionEngine: draft.detectionEngine,
                        defaultTargetLanguage: draft.defaultTargetLanguage,
                        proxyType: draft.proxyType,
                        proxyHost: draft.proxyHost,
                        proxyPort: draft.proxyPort,
                        proxyUsername: draft.proxyUsername,
                        proxyPassword: draft.proxyPassword,
                        noProxyTargets: draft.noProxyTargets,
                        alwaysOnTop: viewModel.preferences.alwaysOnTop,
                        splitRatio: viewModel.preferences.splitRatio,
                        shortcutShowWindow: draft.shortcutShowWindow,
                        shortcutToggleMode: draft.shortcutToggleMode,
                        shortcutQuickCopy: draft.shortcutQuickCopy,
                        sendKey: draft.sendKey,
                        historyMaxRecords: draft.historyMaxRecords
                    )
                    viewModel.preferences = newPrefs
                    viewModel.savePreferences()
                    withAnimation(Animations.bouncySpring) { saveCheckVisible = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await MainActor.run { withAnimation(Animations.standard) { saveCheckVisible = false } }
                    }
                }) {
                    ZStack {
                        Text(L10n.tr("common.save", lang: viewModel.preferences.appLanguage))
                            .opacity(saveCheckVisible ? 0 : 1)
                            .scaleEffect(saveCheckVisible ? 0.5 : 1.0)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                            .opacity(saveCheckVisible ? 1 : 0)
                            .scaleEffect(saveCheckVisible ? 1.2 : 0.5)
                    }
                    .animation(Animations.bouncySpring, value: saveCheckVisible)
                }
                .buttonCursor()
                .disabled(!canSave)
            }
            .padding(16)
            .background(.bar)
        }

        .alert(L10n.tr("settings.reset.confirm.title", lang: viewModel.preferences.appLanguage), isPresented: $resetConfirmPresented) {
            Button(L10n.tr("common.cancel", lang: viewModel.preferences.appLanguage), role: .cancel) {}
                .buttonCursor()
            Button(L10n.tr("common.reset", lang: viewModel.preferences.appLanguage), role: .destructive) {
                // Load defaults into draft only; requires explicit Save to apply
                draft.load(from: Preferences())
            }
            .buttonCursor()
        } message: {
            Text(L10n.tr("settings.reset.confirm.message", lang: viewModel.preferences.appLanguage))
        }
        .background(
            // 设置窗口层级适配器：确保设置窗口总是显示在主窗口之上
            SettingsWindowLevelAdapter()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .onAppear {
            draft.load(from: viewModel.preferences)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: AppViewModel())
            .frame(width: 520, height: 420)
    }
}

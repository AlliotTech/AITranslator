import SwiftUI

enum SettingsLayout {
    static let contentWidth: CGFloat = 536
    static let labelWidth: CGFloat = 128
    static let pageHorizontalPadding: CGFloat = 24
    static let pageVerticalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 18
    static let columnSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 12
}

struct SettingsPage<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsLayout.sectionSpacing) {
                Text(title)
                    .headlineStyle()
                    .foregroundStyle(.primary)

                content
            }
            .frame(maxWidth: SettingsLayout.contentWidth, alignment: .leading)
            .padding(.horizontal, SettingsLayout.pageHorizontalPadding)
            .padding(.vertical, SettingsLayout.pageVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsFormGrid<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Grid(horizontalSpacing: SettingsLayout.columnSpacing, verticalSpacing: SettingsLayout.rowSpacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func settingsFieldLabel() -> some View {
        foregroundStyle(.secondary)
            .frame(width: SettingsLayout.labelWidth, alignment: .trailing)
            .padding(.top, 3)
    }

    func settingsFieldControl() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    @StateObject private var draft = Preferences()

    @State private var revealAPIKey: Bool = false
    @State private var revealDeepLAPIKey: Bool = false
    @State private var apiConnectionTestState: APIConnectionTestState = .idle
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
        return draft.translationProvider != p.translationProvider
            || draft.baseURL != p.baseURL
            || draft.model != p.model
            || draft.apiKey != p.apiKey
            || draft.deepLBaseURL != p.deepLBaseURL
            || draft.deepLAPIKey != p.deepLAPIKey
            || draft.deepLAPIFamily != p.deepLAPIFamily
            || draft.deepLCustomCapability != p.deepLCustomCapability
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
        VStack(spacing: 0) {
            TabView {
                GeneralSettingsSection(draft: draft, viewModel: viewModel)
                    .tabItem { Label(L10n.tr("settings.tab.general", lang: viewModel.preferences.appLanguage), systemImage: "gearshape") }

                APISettingsSection(
                    draft: draft,
                    viewModel: viewModel,
                    revealAPIKey: $revealAPIKey,
                    revealDeepLAPIKey: $revealDeepLAPIKey,
                    connectionTestState: $apiConnectionTestState
                )
                    .tabItem { Label(L10n.tr("settings.tab.api", lang: viewModel.preferences.appLanguage), systemImage: "key") }

                ProxySettingsSection(draft: draft, viewModel: viewModel, proxyTestState: $proxyTestState)
                    .tabItem { Label(L10n.tr("settings.tab.proxy", lang: viewModel.preferences.appLanguage), systemImage: "globe") }

                HotkeysSettingsSection(
                    draft: draft,
                    viewModel: viewModel,
                    sendKeyHelpPresented: $sendKeyHelpPresented,
                    showWindowHelpPresented: $showWindowHelpPresented,
                    toggleModeHelpPresented: $toggleModeHelpPresented,
                    quickCopyHelpPresented: $quickCopyHelpPresented
                )
                .tabItem { Label(L10n.tr("settings.tab.hotkeys", lang: viewModel.preferences.appLanguage), systemImage: "keyboard") }
            }

            settingsFooter
        }
        .controlSize(.regular)
        .background(AppColors.windowBackground)
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

    private var settingsFooter: some View {
        VStack(spacing: 0) {
            Divider()

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

                Spacer(minLength: 12)

                Text(L10n.tr("common.changesNotAutoSaved", lang: viewModel.preferences.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 220, alignment: .trailing)

                Button(action: savePreferences) {
                    ZStack {
                        Text(L10n.tr("common.save", lang: viewModel.preferences.appLanguage))
                            .opacity(saveCheckVisible ? 0 : 1)
                            .scaleEffect(saveCheckVisible ? 0.5 : 1.0)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                            .opacity(saveCheckVisible ? 1 : 0)
                            .scaleEffect(saveCheckVisible ? 1.2 : 0.5)
                    }
                    .frame(minWidth: 44)
                    .animation(Animations.bouncySpring, value: saveCheckVisible)
                }
                .keyboardShortcut(.defaultAction)
                .buttonCursor()
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private func savePreferences() {
        let newPrefs = Preferences(
            translationProvider: draft.translationProvider,
            appLanguage: draft.appLanguage,
            baseURL: draft.baseURL,
            model: draft.model,
            apiKey: draft.apiKey,
            deepLBaseURL: draft.deepLBaseURL,
            deepLAPIKey: draft.deepLAPIKey,
            deepLAPIFamily: draft.deepLAPIFamily,
            deepLCustomCapability: draft.deepLCustomCapability,
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
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: AppViewModel())
            .frame(width: 660, height: 480)
    }
}

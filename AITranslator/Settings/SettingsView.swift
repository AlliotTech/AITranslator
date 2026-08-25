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
    @Environment(\.l10n)
    private var l10n

    @State private var draft = Preferences()

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

    /// 待保存的偏好：设置面板不管理 alwaysOnTop / splitRatio，故沿用当前运行时值
    private var pendingPreferences: Preferences {
        var next = draft
        next.alwaysOnTop = viewModel.preferences.alwaysOnTop
        next.splitRatio = viewModel.preferences.splitRatio
        next.defaultTargetLanguage = LanguageUtils.coerceToSupported(code: draft.defaultTargetLanguage)
        return next
    }

    private var hasChanges: Bool { pendingPreferences != viewModel.preferences }

    private var canSave: Bool { draft.isValid && hasChanges }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralSettingsSection(draft: $draft, viewModel: viewModel)
                    .tabItem { Label(l10n("settings.tab.general"), systemImage: "gearshape") }

                APISettingsSection(
                    draft: $draft,
                    viewModel: viewModel,
                    revealAPIKey: $revealAPIKey,
                    revealDeepLAPIKey: $revealDeepLAPIKey,
                    connectionTestState: $apiConnectionTestState
                )
                    .tabItem { Label(l10n("settings.tab.api"), systemImage: "key") }

                ProxySettingsSection(draft: $draft, viewModel: viewModel, proxyTestState: $proxyTestState)
                    .tabItem { Label(l10n("settings.tab.proxy"), systemImage: "globe") }

                HotkeysSettingsSection(
                    draft: $draft,
                    viewModel: viewModel,
                    sendKeyHelpPresented: $sendKeyHelpPresented,
                    showWindowHelpPresented: $showWindowHelpPresented,
                    toggleModeHelpPresented: $toggleModeHelpPresented,
                    quickCopyHelpPresented: $quickCopyHelpPresented
                )
                .tabItem { Label(l10n("settings.tab.hotkeys"), systemImage: "keyboard") }
            }

            settingsFooter
        }
        .controlSize(.regular)
        .background(AppColors.windowBackground)
        .alert(l10n("settings.reset.confirm.title"), isPresented: $resetConfirmPresented) {
            Button(l10n("common.cancel"), role: .cancel) {}
                .buttonCursor()
            Button(l10n("common.reset"), role: .destructive) {
                // Load defaults into draft only; requires explicit Save to apply
                draft = Preferences()
            }
            .buttonCursor()
        } message: {
            Text(l10n("settings.reset.confirm.message"))
        }
        .background(
            // 设置窗口层级适配器：确保设置窗口总是显示在主窗口之上
            SettingsWindowLevelAdapter()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .onAppear {
            draft = viewModel.preferences
        }
    }

    private var settingsFooter: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 8) {
                Button(l10n("common.resetDefaults")) {
                    resetConfirmPresented = true
                }
                .buttonCursor()

                Button(l10n("common.import")) {
                    if let imported = viewModel.importPreferencesFromJSON() {
                        // Load into draft only; user must click Save to apply
                        draft = imported
                    }
                }
                .buttonCursor()

                Button(l10n("common.export")) {
                    viewModel.exportPreferencesToJSON()
                }
                .buttonCursor()

                Spacer(minLength: 12)

                Text(l10n("common.changesNotAutoSaved"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 220, alignment: .trailing)

                Button(action: savePreferences) {
                    ZStack {
                        Text(l10n("common.save"))
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
        viewModel.preferences = pendingPreferences
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

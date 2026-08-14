import SwiftUI

struct ProxySettingsSection: View {
    @ObservedObject var draft: Preferences
    let viewModel: AppViewModel
    @Binding var proxyTestState: SettingsView.ProxyTestState

    var body: some View {
        SettingsPage(L10n.tr("settings.proxy.title", lang: viewModel.preferences.appLanguage)) {
            SettingsFormGrid {
                GridRow {
                    fieldLabel("settings.proxy.type")
                    Picker("", selection: $draft.proxyType) {
                        ForEach(ProxyType.allCases) { t in
                            switch t {
                            case .none:
                                Text(L10n.tr("proxy.none", lang: viewModel.preferences.appLanguage)).tag(t)
                            case .http:
                                Text(L10n.tr("proxy.http", lang: viewModel.preferences.appLanguage)).tag(t)
                            case .socks5:
                                Text(L10n.tr("proxy.socks5", lang: viewModel.preferences.appLanguage)).tag(t)
                            }
                        }
                    }
                    .labelsHidden()
                    .settingsFieldControl()
                    .onChange(of: draft.proxyType) { _, _ in
                        proxyTestState = .idle
                    }
                }

                if draft.proxyType != .none {
                    GridRow {
                        fieldLabel("settings.proxy.hostPort")
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                TextField(L10n.tr("settings.proxy.host.placeholder", lang: viewModel.preferences.appLanguage), text: $draft.proxyHost)
                                    .onChange(of: draft.proxyHost) { _, newValue in
                                        draft.proxyHost = newValue.trimmingCharacters(in: .whitespaces)
                                        proxyTestState = .idle
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                            .opacity(draft.isProxyHostValid ? 0 : 1)
                                    )
                                TextField(
                                    L10n.tr("settings.proxy.port.placeholder", lang: viewModel.preferences.appLanguage),
                                    value: $draft.proxyPort,
                                    format: .number.grouping(.never)
                                )
                                .frame(width: 80)
                                .onChange(of: draft.proxyPort) { oldValue, newValue in
                                    if newValue < 1 {
                                        draft.proxyPort = 1
                                    } else if newValue > 65535 {
                                        draft.proxyPort = 65535
                                    }
                                    proxyTestState = .idle
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                        .opacity(draft.isProxyPortValid ? 0 : 1)
                                )
                            }

                            if !draft.isProxyValid {
                                Text(L10n.tr("settings.proxy.invalid", lang: viewModel.preferences.appLanguage))
                                    .footnoteStyle()
                                    .foregroundStyle(AppColors.error)
                            }
                        }
                        .settingsFieldControl()
                    }

                    GridRow {
                        fieldLabel("settings.proxy.noProxyTargets")
                        TextField(
                            L10n.tr("settings.proxy.noProxyTargets.placeholder", lang: viewModel.preferences.appLanguage),
                            text: $draft.noProxyTargets,
                            prompt: Text("localhost,127.0.0.1")
                        )
                        .settingsFieldControl()
                        .onChange(of: draft.noProxyTargets) { _, newValue in
                            draft.noProxyTargets = newValue
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .joined(separator: ",")
                            proxyTestState = .idle
                        }
                        .help(L10n.tr("settings.proxy.noProxyTargets.help", lang: viewModel.preferences.appLanguage))
                    }

                    GridRow {
                        fieldLabel("settings.proxy.credentials")
                        HStack(spacing: 8) {
                            TextField(L10n.tr("settings.proxy.username.placeholder", lang: viewModel.preferences.appLanguage), text: $draft.proxyUsername)
                                .onChange(of: draft.proxyUsername) { _, newValue in
                                    draft.proxyUsername = newValue.trimmingCharacters(in: .whitespaces)
                                    proxyTestState = .idle
                                }
                            SecureField(L10n.tr("settings.proxy.password.placeholder", lang: viewModel.preferences.appLanguage), text: $draft.proxyPassword)
                                .onChange(of: draft.proxyPassword) { _, newValue in
                                    draft.proxyPassword = newValue.trimmingCharacters(in: .whitespaces)
                                    proxyTestState = .idle
                                }
                        }
                        .settingsFieldControl()
                    }

                    GridRow {
                        Text("")
                            .settingsFieldLabel()
                            .accessibilityHidden(true)
                        HStack(spacing: 8) {
                            Button(L10n.tr("settings.proxy.test", lang: viewModel.preferences.appLanguage), action: testProxy)
                                .buttonCursor()
                                .disabled(!draft.isProxyValid || proxyTestState == .testing)

                            ZStack {
                                switch proxyTestState {
                                case .idle:
                                    Color.clear
                                case .testing:
                                    ProgressView().controlSize(.small)
                                case .success:
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success)
                                case .failure:
                                    Image(systemName: "xmark.octagon.fill").foregroundColor(AppColors.error)
                                }
                            }
                            .frame(width: 18, height: 18)
                        }
                        .settingsFieldControl()
                    }
                }
            }
        }
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(L10n.tr(key, lang: viewModel.preferences.appLanguage))
            .settingsFieldLabel()
    }

    private func testProxy() {
        withAnimation(.none) { proxyTestState = .testing }
        let host = draft.proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = draft.proxyPort
        guard !host.isEmpty, (1...65535).contains(port) else {
            withAnimation(.none) { proxyTestState = .failure }
            return
        }

        let username = draft.proxyUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = draft.proxyPassword
        let proxy = HTTPClient.ProxySettings(
            type: draft.proxyType,
            host: host,
            port: port,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            noProxyHosts: []
        )

        Task {
            let isReachable = await HTTPClient.testProxy(proxy)
            await MainActor.run {
                withAnimation(.none) {
                    proxyTestState = isReachable ? .success : .failure
                }
            }
        }
    }
}

import SwiftUI

struct ProxySettingsSection: View {
    @Binding var draft: Preferences
    let viewModel: AppViewModel
    @Binding var proxyTestState: SettingsView.ProxyTestState
    @Environment(\.l10n)
    private var l10n

    var body: some View {
        SettingsPage(l10n("settings.proxy.title")) {
            SettingsFormGrid {
                GridRow {
                    fieldLabel("settings.proxy.type")
                    Picker("", selection: $draft.proxyType) {
                        ForEach(ProxyType.allCases) { type in
                            switch type {
                            case .none:
                                Text(l10n("proxy.none")).tag(type)
                            case .http:
                                Text(l10n("proxy.http")).tag(type)
                            case .socks5:
                                Text(l10n("proxy.socks5")).tag(type)
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
                                TextField(l10n("settings.proxy.host.placeholder"), text: $draft.proxyHost)
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
                                    l10n("settings.proxy.port.placeholder"),
                                    value: $draft.proxyPort,
                                    format: .number.grouping(.never)
                                )
                                .frame(width: 80)
                                .onChange(of: draft.proxyPort) { _, newValue in
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
                                Text(l10n("settings.proxy.invalid"))
                                    .footnoteStyle()
                                    .foregroundStyle(AppColors.error)
                            }
                        }
                        .settingsFieldControl()
                    }

                    GridRow {
                        fieldLabel("settings.proxy.noProxyTargets")
                        TextField(
                            l10n("settings.proxy.noProxyTargets.placeholder"),
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
                        .help(l10n("settings.proxy.noProxyTargets.help"))
                    }

                    GridRow {
                        fieldLabel("settings.proxy.credentials")
                        HStack(spacing: 8) {
                            TextField(l10n("settings.proxy.username.placeholder"), text: $draft.proxyUsername)
                                .onChange(of: draft.proxyUsername) { _, newValue in
                                    draft.proxyUsername = newValue.trimmingCharacters(in: .whitespaces)
                                    proxyTestState = .idle
                                }
                            SecureField(l10n("settings.proxy.password.placeholder"), text: $draft.proxyPassword)
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
                            Button(l10n("settings.proxy.test"), action: testProxy)
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
        Text(l10n(key))
            .settingsFieldLabel()
    }

    func testProxy() {
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

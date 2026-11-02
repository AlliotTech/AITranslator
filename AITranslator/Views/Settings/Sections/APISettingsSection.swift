import SwiftUI

enum APIConnectionTestState: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}

struct APISettingsSection: View {
    @Binding var draft: Preferences
    let viewModel: AppViewModel
    @Binding var revealAPIKey: Bool
    @Binding var revealDeepLAPIKey: Bool
    @Binding var connectionTestState: APIConnectionTestState
    @Environment(\.l10n)
    private var l10n

    var body: some View {
        SettingsPage(l10n("settings.api.title")) {
            SettingsFormGrid {
                GridRow {
                    fieldLabel("settings.api.provider")
                    Picker("", selection: $draft.translationProvider) {
                        providerOption(.openAI, key: "provider.openAI")
                        providerOption(.deepLFree, key: "provider.deepLFree")
                        providerOption(.deepLPro, key: "provider.deepLPro")
                        providerOption(.deepLCustom, key: "provider.deepLCustom")
                    }
                    .labelsHidden()
                    .settingsFieldControl()
                    .onChange(of: draft.translationProvider) { _, _ in
                        connectionTestState = .idle
                    }
                }

                if draft.translationProvider == .openAI {
                    openAIFields
                } else {
                    deepLFields
                }
            }

            if draft.translationProvider == .deepLCustom {
                Label(
                    l10n("settings.api.deepL.custom.warning"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, SettingsLayout.labelWidth + SettingsLayout.columnSpacing)
            }
        }
    }

    @ViewBuilder private var openAIFields: some View {
        GridRow {
            fieldLabel("settings.api.baseURL")
            validatedField(
                text: $draft.baseURL,
                placeholder: "settings.api.baseURL.placeholder",
                help: "settings.api.baseURL.help",
                isValid: draft.isBaseURLValid,
                invalidKey: "settings.api.baseURL.invalid"
            )
            .settingsFieldControl()
        }

        GridRow {
            fieldLabel("settings.api.model")
            validatedField(
                text: $draft.model,
                placeholder: "settings.api.model.placeholder",
                help: nil,
                isValid: draft.isModelValid,
                invalidKey: "settings.api.model.invalid"
            )
            .settingsFieldControl()
        }

        GridRow {
            fieldLabel("settings.api.ocrModel")
            validatedField(
                text: $draft.ocrModel,
                placeholder: "settings.api.ocrModel.placeholder",
                help: "settings.api.ocrModel.help",
                isValid: true,
                invalidKey: ""
            )
            .settingsFieldControl()
        }

        GridRow {
            fieldLabel("settings.api.key")
            secureField(
                text: $draft.apiKey,
                isRevealed: $revealAPIKey,
                isValid: draft.isAPIKeyValid,
                invalidKey: "settings.api.key.invalid"
            )
            .settingsFieldControl()
        }
    }

    @ViewBuilder private var deepLFields: some View {
        if draft.translationProvider == .deepLCustom {
            GridRow {
                fieldLabel("settings.api.deepL.protocol")
                Picker("", selection: $draft.deepLAPIFamily) {
                    Text(l10n("settings.api.deepL.protocol.v2"))
                        .tag(DeepLAPIFamily.officialV2)
                    Text(l10n("settings.api.deepL.protocol.legacy"))
                        .tag(DeepLAPIFamily.legacyDeepLX)
                }
                .labelsHidden()
                .settingsFieldControl()
                .onChange(of: draft.deepLAPIFamily) { _, family in
                    if family == .legacyDeepLX {
                        draft.deepLCustomCapability = .translateOnly
                    }
                    connectionTestState = .idle
                }
            }

            GridRow {
                fieldLabel("settings.api.deepL.baseURL")
                validatedField(
                    text: $draft.deepLBaseURL,
                    placeholder: "settings.api.deepL.baseURL.placeholder",
                    help: "settings.api.deepL.baseURL.help",
                    isValid: draft.isDeepLBaseURLValid,
                    invalidKey: "settings.api.deepL.baseURL.invalid"
                )
                .settingsFieldControl()
            }

            GridRow {
                fieldLabel("settings.api.deepL.capability")
                Picker("", selection: $draft.deepLCustomCapability) {
                    Text(l10n("settings.api.deepL.capability.translateOnly"))
                        .tag(DeepLCustomCapability.translateOnly)
                    Text(l10n("settings.api.deepL.capability.write"))
                        .tag(DeepLCustomCapability.translateAndWrite)
                }
                .labelsHidden()
                .settingsFieldControl()
                .disabled(draft.deepLAPIFamily == .legacyDeepLX)
                .onChange(of: draft.deepLCustomCapability) { _, _ in
                    connectionTestState = .idle
                }
            }
        } else {
            GridRow {
                fieldLabel("settings.api.deepL.baseURL")
                readOnlyField(draft.resolvedDeepLBaseURL)
                    .settingsFieldControl()
            }
        }

        GridRow {
            fieldLabel("settings.api.deepL.key")
            secureField(
                text: $draft.deepLAPIKey,
                isRevealed: $revealDeepLAPIKey,
                isValid: draft.isDeepLAPIKeyValid,
                invalidKey: "settings.api.deepL.key.invalid"
            )
            .settingsFieldControl()
        }

        GridRow {
            fieldLabel("settings.api.deepL.test")
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Button(l10n("settings.api.deepL.test")) {
                        connectionTestState = .testing
                        Task {
                            do {
                                let result = try await viewModel.testDeepLConnection(preferences: draft)
                                let key = result.rephrasedText == nil
                                    ? "settings.api.deepL.test.success.translate"
                                    : "settings.api.deepL.test.success.write"
                                connectionTestState = .success(l10n(key))
                            } catch {
                                connectionTestState = .failure(error.localizedDescription)
                            }
                        }
                    }
                    .buttonCursor()
                    .disabled(!draft.isValid || connectionTestState == .testing)

                    if connectionTestState == .testing {
                        ProgressView().controlSize(.small)
                    }
                }

                switch connectionTestState {
                case .success(let message):
                    Text(message).foregroundStyle(AppColors.success).font(.caption)
                case .failure(let message):
                    Text(message).foregroundStyle(AppColors.error).font(.caption).textSelection(.enabled)
                case .idle, .testing:
                    Text(l10n("settings.api.deepL.test.help"))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .settingsFieldControl()
        }
    }

    private func providerOption(_ provider: TranslationProviderKind, key: String) -> some View {
        Text(l10n(key)).tag(provider)
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(l10n(key))
            .settingsFieldLabel()
    }

    private func readOnlyField(_ value: String) -> some View {
        Text(value)
            .font(.callout.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppColors.contentBackground.opacity(0.7))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(AppColors.borderNormal, lineWidth: 1)
            }
    }

    private func validatedField(
        text: Binding<String>,
        placeholder: String,
        help: String?,
        isValid: Bool,
        invalidKey: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(
                "",
                text: text,
                prompt: Text(l10n(placeholder))
            )
            .help(help.map { l10n($0) } ?? "")
            .onChange(of: text.wrappedValue) { _, newValue in
                text.wrappedValue = newValue.trimmingCharacters(in: .whitespaces)
                connectionTestState = .idle
            }
            .overlay(validationBorder(isValid: isValid))

            if !isValid {
                Text(l10n(invalidKey))
                    .footnoteStyle()
                    .foregroundStyle(AppColors.error)
            }
        }
    }

    private func secureField(
        text: Binding<String>,
        isRevealed: Binding<Bool>,
        isValid: Bool,
        invalidKey: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Group {
                    if isRevealed.wrappedValue {
                        TextField("", text: text)
                    } else {
                        SecureField("", text: text)
                    }
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    text.wrappedValue = newValue.trimmingCharacters(in: .whitespaces)
                    connectionTestState = .idle
                }
                .overlay(validationBorder(isValid: isValid))

                Button {
                    isRevealed.wrappedValue.toggle()
                } label: {
                    Image(systemName: isRevealed.wrappedValue ? "eye.slash" : "eye")
                }
                .buttonCursor()
            }

            if !isValid {
                Text(l10n(invalidKey))
                    .footnoteStyle()
                    .foregroundStyle(AppColors.error)
            }
        }
    }

    private func validationBorder(isValid: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.red.opacity(0.6), lineWidth: 1)
            .opacity(isValid ? 0 : 1)
    }
}

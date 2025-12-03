import SwiftUI

struct APISettingsSection: View {
    @ObservedObject var draft: Preferences
    let viewModel: AppViewModel
    @Binding var revealAPIKey: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("settings.api.title", lang: viewModel.preferences.appLanguage))
                .headlineStyle()
                .foregroundColor(.primary)
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text(L10n.tr("settings.api.baseURL", lang: viewModel.preferences.appLanguage))
                    VStack(alignment: .leading, spacing: 2) {
                        TextField(
                            "",
                            text: $draft.baseURL,
                            prompt: Text(L10n.tr("settings.api.baseURL.placeholder", lang: viewModel.preferences.appLanguage))
                        )
                        .help(L10n.tr("settings.api.baseURL.help", lang: viewModel.preferences.appLanguage))
                        .onChange(of: draft.baseURL) { _, newValue in
                            draft.baseURL = newValue.trimmingCharacters(in: .whitespaces)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                .opacity(draft.isBaseURLValid ? 0 : 1)
                        )

                        if !draft.isBaseURLValid {
                            Text(L10n.tr("settings.api.baseURL.invalid", lang: viewModel.preferences.appLanguage))
                                .footnoteStyle()
                                .foregroundColor(AppColors.error)
                        }
                    }
                }

                GridRow {
                    Text(L10n.tr("settings.api.model", lang: viewModel.preferences.appLanguage))
                    VStack(alignment: .leading, spacing: 2) {
                        TextField(
                            "",
                            text: $draft.model,
                            prompt: Text(L10n.tr("settings.api.model.placeholder", lang: viewModel.preferences.appLanguage))
                        )
                        .onChange(of: draft.model) { _, newValue in
                            draft.model = newValue.trimmingCharacters(in: .whitespaces)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                .opacity(draft.isModelValid ? 0 : 1)
                        )

                        if !draft.isModelValid {
                            Text(L10n.tr("settings.api.model.invalid", lang: viewModel.preferences.appLanguage))
                                .footnoteStyle()
                                .foregroundColor(AppColors.error)
                        }
                    }
                }

                GridRow {
                    Text(L10n.tr("settings.api.key", lang: viewModel.preferences.appLanguage))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            if revealAPIKey {
                                TextField("", text: $draft.apiKey)
                                    .onChange(of: draft.apiKey) { _, newValue in
                                        draft.apiKey = newValue.trimmingCharacters(in: .whitespaces)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                            .opacity(draft.isAPIKeyValid ? 0 : 1)
                                    )
                            } else {
                                SecureField("", text: $draft.apiKey)
                                    .onChange(of: draft.apiKey) { _, newValue in
                                        draft.apiKey = newValue.trimmingCharacters(in: .whitespaces)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                            .opacity(draft.isAPIKeyValid ? 0 : 1)
                                    )
                            }
                            Button(action: { revealAPIKey.toggle() }) {
                                Image(systemName: revealAPIKey ? "eye.slash" : "eye")
                            }
                            .buttonCursor()
                        }

                        if !draft.isAPIKeyValid {
                            Text(L10n.tr("settings.api.key.invalid", lang: viewModel.preferences.appLanguage))
                                .footnoteStyle()
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

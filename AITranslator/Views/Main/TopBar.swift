import SwiftUI

struct TopBar: View {
    @ObservedObject var viewModel: AppViewModel
    var temporarilyBlurAndRefocus: () -> Void
    @Environment(\.undoManager) private var undoManager
    @State private var isSwapping = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Picker(L10n.tr("picker.source", lang: viewModel.preferences.appLanguage), selection: Binding(
                    get: { viewModel.session.sourceLang },
                    set: { viewModel.setSourceLang($0) }
                )) {
                    ForEach(LanguageUtils.supported) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
                .frame(width: 160)
                .disabled(viewModel.session.mode == .summarize)
                .help(L10n.tr("picker.source.help", lang: viewModel.preferences.appLanguage))
                .onChange(of: viewModel.session.sourceLang) { _, _ in
                    temporarilyBlurAndRefocus()
                }

                Button(action: {
                    temporarilyBlurAndRefocus()
                    let prevSrc = viewModel.session.sourceLang
                    let prevTgt = viewModel.session.targetLang
                    if viewModel.session.mode == .translate {
                        // 触发旋转动画
                        withAnimation(Animations.bouncySpring) {
                            isSwapping = true
                        }

                        viewModel.swapLanguages()
                        undoManager?.registerUndo(withTarget: viewModel) { vm in
                            vm.restoreLanguages(source: prevSrc, target: prevTgt)
                        }

                        // 动画结束后重置
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isSwapping = false
                        }
                    }
                }) {
                    Label(L10n.tr("cmd.swapLanguages", lang: viewModel.preferences.appLanguage), systemImage: "arrow.left.arrow.right.circle")
                        .labelStyle(.iconOnly)
                        .rotationEffect(isSwapping ? .degrees(180) : .zero)
                        .animation(Animations.bouncySpring, value: isSwapping)
                }
                .secondaryBorderedButton()
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .help(viewModel.session.mode == .polish || viewModel.session.mode == .summarize ? L10n.tr("picker.swap.disabled", lang: viewModel.preferences.appLanguage) : L10n.tr("picker.swap.help", lang: viewModel.preferences.appLanguage))
                .disabled(
                    viewModel.session.mode == .polish ||
                    viewModel.session.mode == .summarize ||
                    LanguageUtils.standardize(code: viewModel.session.sourceLang).lowercased() ==
                    LanguageUtils.standardize(code: viewModel.session.targetLang).lowercased()
                )
                .accessibilityLabel(L10n.tr("picker.swap.a11y", lang: viewModel.preferences.appLanguage))
                .accessibilityHint(L10n.tr("picker.swap.hint", lang: viewModel.preferences.appLanguage))

                Picker(L10n.tr("picker.target", lang: viewModel.preferences.appLanguage), selection: Binding(
                    get: { viewModel.session.targetLang },
                    set: { viewModel.setTargetLang($0) }
                )) {
                    ForEach(LanguageUtils.supported) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
                .frame(width: 160)
                .disabled(viewModel.session.mode == .polish)
                .help(L10n.tr("picker.target.help", lang: viewModel.preferences.appLanguage))
                .onChange(of: viewModel.session.targetLang) { _, _ in
                    temporarilyBlurAndRefocus()
                }
            }

            Spacer()

            ModePicker(
                selection: viewModel.session.mode,
                isAvailable: viewModel.isModeAvailable,
                appLanguage: viewModel.preferences.appLanguage,
                onSelect: { mode in
                    temporarilyBlurAndRefocus()
                    viewModel.setMode(mode)
                }
            )
            .help(L10n.tr("picker.mode.help", lang: viewModel.preferences.appLanguage))
            .accessibilityLabel(L10n.tr("picker.mode", lang: viewModel.preferences.appLanguage))
            .accessibilityHint(L10n.tr("picker.mode.help", lang: viewModel.preferences.appLanguage))
        }
        .padding(.horizontal, Metrics.outerPadding)
        .padding(.top, Metrics.outerPadding)
    }
}

private struct ModePicker: View {
    let selection: AppMode
    let isAvailable: (AppMode) -> Bool
    let appLanguage: AppLanguage
    let onSelect: (AppMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppMode.allCases) { mode in
                let available = isAvailable(mode)
                Button(action: { onSelect(mode) }) {
                    Text(title(for: mode))
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(foregroundStyle(for: mode, available: available))
                .background(selection == mode ? Color.accentColor : Color.clear)
                .disabled(!available)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(AppColors.borderNormal, lineWidth: 0.5)
        }
    }

    private func title(for mode: AppMode) -> String {
        switch mode {
        case .translate:
            return L10n.tr("mode.translate", lang: appLanguage)
        case .polish:
            return L10n.tr("mode.polish", lang: appLanguage)
        case .summarize:
            return L10n.tr("mode.summarize", lang: appLanguage)
        }
    }

    private func foregroundStyle(for mode: AppMode, available: Bool) -> Color {
        if !available {
            return .secondary.opacity(0.45)
        }
        return selection == mode ? .white : .primary
    }
}

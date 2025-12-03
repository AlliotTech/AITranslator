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
                            vm.session.sourceLang = prevSrc
                            vm.session.targetLang = prevTgt
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

            Picker(L10n.tr("picker.mode", lang: viewModel.preferences.appLanguage), selection: $viewModel.session.mode) {
                ForEach(AppMode.allCases) { mode in
                    switch mode {
                    case .translate:
                        Text(L10n.tr("mode.translate", lang: viewModel.preferences.appLanguage)).tag(mode)
                    case .polish:
                        Text(L10n.tr("mode.polish", lang: viewModel.preferences.appLanguage)).tag(mode)
                    case .summarize:
                        Text(L10n.tr("mode.summarize", lang: viewModel.preferences.appLanguage)).tag(mode)
                    }
                }
            }
            .pickerStyle(.segmented)
            .help(L10n.tr("picker.mode.help", lang: viewModel.preferences.appLanguage))
            .accessibilityLabel(L10n.tr("picker.mode", lang: viewModel.preferences.appLanguage))
            .accessibilityHint(L10n.tr("picker.mode.help", lang: viewModel.preferences.appLanguage))
            .onChange(of: viewModel.session.mode) { oldMode, newMode in
                temporarilyBlurAndRefocus()
                viewModel.onModeChanged(from: oldMode, to: newMode)
                if !viewModel.session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.send()
                }
            }
        }
        .padding(.horizontal, Metrics.outerPadding)
        .padding(.top, Metrics.outerPadding)
    }
}

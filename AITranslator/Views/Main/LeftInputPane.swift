import SwiftUI

struct LeftInputPane: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var inputFocused: Bool
    var forceFocusToken: Int

    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var clearButtonPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("section.input", lang: viewModel.preferences.appLanguage))
                    .headlineStyle()
                    .foregroundColor(.primary)
                Spacer()
            }
            PlaceholderTextEditor(
                text: Binding(
                    get: { viewModel.session.input },
                    set: { viewModel.onInputChanged($0) }
                ),
                isFocused: $inputFocused,
                placeholder: L10n.tr(viewModel.preferences.sendKey == .enter ? "input.placeholder.enter" : "input.placeholder.cmdEnter", lang: viewModel.preferences.appLanguage),
                sendOnEnter: viewModel.preferences.sendKey == .enter,
                onSubmit: { viewModel.send() },
                // When user pastes into input, schedule a short-delayed language detection
                onExternalPaste: { viewModel.scheduleDetectionAfterPaste() },
                forceFocusToken: forceFocusToken
            )
            .frame(minHeight: Metrics.minPaneHeight)
            .multilineTextAlignment(.leading)
            .environment(\.layoutDirection, LanguageUtils.isRTLLanguage(code: viewModel.session.sourceLang) ? .rightToLeft : .leftToRight)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.paneCornerRadius, style: .continuous))
            .paneStyle(isFocused: inputFocused, differentiateWithoutColor: differentiateWithoutColor)
            .overlay(alignment: .bottomTrailing) {
                Button(action: {
                    // 触发按钮动画
                    withAnimation(Animations.spring) {
                        clearButtonPressed = true
                    }

                    let prevIn = viewModel.session.input
                    let prevOut = viewModel.session.output
                    viewModel.session.input = ""
                    viewModel.session.output = ""
                    viewModel.resetOverridesAfterClear()
                    undoManager?.registerUndo(withTarget: viewModel) { vm in
                        vm.session.input = prevIn
                        vm.session.output = prevOut
                    }

                    // 动画结束后重置
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        clearButtonPressed = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .scaleEffect(clearButtonPressed ? 0.85 : 1.0)
                        .animation(Animations.spring, value: clearButtonPressed)
                }
                .buttonStyle(OverlayIconButtonStyle())
                .help(L10n.tr("input.clear.help", lang: viewModel.preferences.appLanguage))
                .accessibilityLabel(L10n.tr("input.clear.a11y", lang: viewModel.preferences.appLanguage))
                .accessibilityHint(L10n.tr("input.clear.hint", lang: viewModel.preferences.appLanguage))
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
                .padding(Metrics.innerPadding)
                .opacity(viewModel.isBothEmpty ? 0.35 : 1)
                .disabled(viewModel.isBothEmpty)
            }
        }
        .frame(minWidth: Metrics.minPaneWidth)
        .padding(.horizontal, Metrics.outerPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.tr("section.input", lang: viewModel.preferences.appLanguage))
        .accessibilityValue(viewModel.session.input)
    }
}

import SwiftUI

struct LeftInputPane: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var inputFocused: Bool
    var forceFocusToken: Int

    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.l10n)
    private var l10n
    @State private var clearButtonPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n("section.input"))
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
                placeholder: l10n(viewModel.preferences.sendKey == .enter ? "input.placeholder.enter" : "input.placeholder.cmdEnter"),
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
                    viewModel.onInputChanged("")
                    viewModel.session.output = ""
                    viewModel.resetOverridesAfterClear()
                    undoManager?.registerUndo(withTarget: viewModel) { vm in
                        vm.restoreAfterClear(input: prevIn, output: prevOut)
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
                .help(l10n("input.clear.help"))
                .accessibilityLabel(l10n("input.clear.a11y"))
                .accessibilityHint(l10n("input.clear.hint"))
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
        .accessibilityLabel(l10n("section.input"))
        .accessibilityValue(viewModel.session.input)
    }
}

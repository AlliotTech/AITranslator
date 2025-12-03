import SwiftUI

struct BottomBar: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var showStreamingSpinner: Bool

    var body: some View {
        HStack(spacing: 8) {
            Spacer()

            // 进度指示器：独立显示在按钮左侧
            if viewModel.session.isStreaming && showStreamingSpinner {
                ProgressView()
                    .controlSize(.small)
                    .transition(.scaleAndFade)
            }

            // 主操作按钮：发送/停止
            if viewModel.session.isStreaming {
                Button(L10n.tr("btn.stop", lang: viewModel.preferences.appLanguage)) {
                    viewModel.stopStreaming()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .primaryProminentButton()
                .tint(.red)
                .help(L10n.tr("btn.stop.help", lang: viewModel.preferences.appLanguage))
                .accessibilityLabel(L10n.tr("btn.stop.a11y", lang: viewModel.preferences.appLanguage))
                .accessibilityHint(L10n.tr("btn.stop.hint", lang: viewModel.preferences.appLanguage))
            } else {
                Button(L10n.tr("btn.send", lang: viewModel.preferences.appLanguage)) {
                    viewModel.send()
                }
                .keyboardShortcut(.return, modifiers: viewModel.preferences.sendKey == .enter ? [] : [.command])
                .primaryProminentButton()
                .disabled(viewModel.isSendDisabled)
                .help(L10n.tr("btn.send.help", lang: viewModel.preferences.appLanguage))
                .accessibilityLabel(L10n.tr("btn.send.a11y", lang: viewModel.preferences.appLanguage))
                .accessibilityHint(L10n.tr("btn.send.hint", lang: viewModel.preferences.appLanguage))
            }
        }
        .padding(.horizontal, Metrics.outerPadding)
        .padding(.bottom, Metrics.outerPadding)
        .animation(Animations.standard, value: viewModel.session.isStreaming)
    }
}

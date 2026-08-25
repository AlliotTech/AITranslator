import SwiftUI

struct BottomBar: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var showStreamingSpinner: Bool
    @Environment(\.l10n)
    private var l10n

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.session.isStreaming,
               viewModel.translationTotalUnits > 1 {
                Text(l10n(
                    "progress.chunks",
                    viewModel.translationCompletedUnits,
                    viewModel.translationTotalUnits
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if !viewModel.session.isStreaming && viewModel.canRetryFromFailure {
                Button(l10n("btn.retry")) {
                    viewModel.retryFromFailure()
                }
                .buttonCursor()
            }

            Spacer()

            // 进度指示器：独立显示在按钮左侧
            if viewModel.session.isStreaming && showStreamingSpinner {
                ProgressView()
                    .controlSize(.small)
                    .transition(.scaleAndFade)
            }

            // 主操作按钮：发送/停止
            if viewModel.session.isStreaming {
                Button(l10n("btn.stop")) {
                    viewModel.stopStreaming()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .primaryProminentButton()
                .tint(.red)
                .help(l10n("btn.stop.help"))
                .accessibilityLabel(l10n("btn.stop.a11y"))
                .accessibilityHint(l10n("btn.stop.hint"))
            } else {
                Button(l10n("btn.send")) {
                    viewModel.send()
                }
                .keyboardShortcut(.return, modifiers: viewModel.preferences.sendKey == .enter ? [] : [.command])
                .primaryProminentButton()
                .disabled(viewModel.isSendDisabled)
                .help(l10n("btn.send.help"))
                .accessibilityLabel(l10n("btn.send.a11y"))
                .accessibilityHint(l10n("btn.send.hint"))
            }
        }
        .padding(.horizontal, Metrics.outerPadding)
        .padding(.bottom, Metrics.outerPadding)
        .animation(Animations.standard, value: viewModel.session.isStreaming)
    }
}

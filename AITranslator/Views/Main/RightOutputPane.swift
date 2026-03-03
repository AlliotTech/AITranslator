import SwiftUI
import Combine

struct RightOutputPane: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var copiedFlash: Bool = false

    // 简化的滚动控制
    @State private var lastScrollTime: Date = .distantPast

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("section.output", lang: viewModel.preferences.appLanguage))
                    .headlineStyle()
                    .foregroundColor(.primary)
                Spacer()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let error = viewModel.session.error {
                            Text(error)
                                .frame(maxWidth: 720, alignment: .leading)
                                .font(Typography.body)
                                // 注意：不使用 .lineSpacing()，因为 .textSelection(.enabled)
                                // 激活时会切换渲染方式，导致行距计算不一致
                                .multilineTextAlignment(.leading)
                                .foregroundColor(AppColors.error)
                                .textSelection(.enabled)
                                .autoTextAlignment(for: viewModel.session.targetLang)
                                // 使用 id 强制刷新，修复窗口隐藏后显示时 textSelection 不渲染的问题
                                .id("error-\(viewModel.outputRefreshToken)")
                        } else if viewModel.session.output.isEmpty {
                            if viewModel.session.isStreaming {
                                HStack(spacing: 6) {
                                    BlinkingCursor()
                                    Text(L10n.tr("streaming", lang: viewModel.preferences.appLanguage))
                                        .bodyStyle(comfortable: false)
                                        .foregroundColor(AppColors.placeholder)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "text.bubble")
                                            .foregroundColor(AppColors.placeholder)
                                        Text(L10n.tr("output.placeholder", lang: viewModel.preferences.appLanguage))
                                            .bodyStyle(comfortable: false)
                                            .foregroundColor(AppColors.placeholder)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                // 主要输出内容
                                OutputTextView(
                                    output: viewModel.session.output,
                                    isStreaming: viewModel.session.isStreaming,
                                    targetLang: viewModel.session.targetLang
                                )

                                // 长文本模式提示（当进入暂停渲染模式时显示）
                                if viewModel.session.isStreaming && viewModel.isInLongTextMode {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                        Text("正在接收大量内容，完成后将显示完整结果...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 8)
                                    .padding(.horizontal, 4)
                                }
                            }
                        }
                        Color.clear.frame(height: 1).id("OUTPUT_BOTTOM")
                    }
                    .padding(Metrics.innerPadding)
                }
                .clipShape(RoundedRectangle(cornerRadius: Metrics.paneCornerRadius, style: .continuous))
                .frame(minHeight: Metrics.minPaneHeight)
                .paneStyle(isFocused: false, differentiateWithoutColor: differentiateWithoutColor)
                .overlay(alignment: .bottomTrailing) {
                    Button(action: { viewModel.copyOutputToClipboard() }) {
                        ZStack {
                            Image(systemName: "doc.on.doc")
                                .opacity(copiedFlash ? 0 : 1)
                                .scaleEffect(copiedFlash ? 0.5 : 1.0)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                                .opacity(copiedFlash ? 1 : 0)
                                .scaleEffect(copiedFlash ? 1.2 : 0.5)
                        }
                        .animation(Animations.bouncySpring, value: copiedFlash)
                    }
                    .buttonStyle(OverlayIconButtonStyle())
                    .help(L10n.tr("output.copy.help", lang: viewModel.preferences.appLanguage))
                    .accessibilityLabel(L10n.tr("output.copy.a11y", lang: viewModel.preferences.appLanguage))
                    .accessibilityHint(L10n.tr("output.copy.hint", lang: viewModel.preferences.appLanguage))
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
                    .padding(Metrics.innerPadding)
                    .opacity(viewModel.isOutputEmpty ? 0.35 : 1)
                    .disabled(viewModel.isOutputEmpty)
                }
                // 性能优化：仅在流式状态变化时滚动
                // 避免频繁的onChange调用
                .onChange(of: viewModel.session.isStreaming) { _, isStreaming in
                    if !isStreaming {
                        // 流式输出完成时，滚动到底部查看完整内容
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo("OUTPUT_BOTTOM", anchor: .bottom)
                        }
                    } else {
                        // 开始流式输出时也滚动一次
                        proxy.scrollTo("OUTPUT_BOTTOM", anchor: .bottom)
                    }
                }
                // 定时兜底滚动
                .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                    if viewModel.session.isStreaming && viewModel.session.output.count < 20000 {
                        let now = Date()
                        if now.timeIntervalSince(lastScrollTime) > 0.5 {
                            lastScrollTime = now
                            proxy.scrollTo("OUTPUT_BOTTOM", anchor: .bottom)
                        }
                    }
                }
                // 事件驱动滚动：流式输出变化时也尝试跟随（带节流）
                .onChange(of: viewModel.session.output.count) { _, _ in
                    guard viewModel.session.isStreaming else { return }
                    guard viewModel.session.output.count < 20000 else { return }

                    let now = Date()
                    guard now.timeIntervalSince(lastScrollTime) > 0.15 else { return }
                    lastScrollTime = now

                    proxy.scrollTo("OUTPUT_BOTTOM", anchor: .bottom)
                }
                .onChange(of: viewModel.copyFeedbackToken) { _, _ in
                    withAnimation(Animations.bouncySpring) { copiedFlash = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        await MainActor.run {
                            withAnimation(Animations.standard) { copiedFlash = false }
                        }
                    }
                }
                // 注意：移除了 .onAppear 中的自动滚动
                // 原因：焦点切换可能导致视图重新创建，触发 onAppear，
                // 导致用户正在查看的内容被滚动走，看起来像"内容丢失"
                // 滚动到底部的逻辑已在 onChange(of: output) 和 onChange(of: isStreaming) 中处理
            }
        }
        .frame(minWidth: Metrics.minPaneWidth)
        .padding(.horizontal, Metrics.outerPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.tr("section.output", lang: viewModel.preferences.appLanguage))
        .accessibilityValue(viewModel.session.output)
    }
}

// MARK: - Output Text View Component

/// 输出文本视图组件
/// 性能优化：根据文本长度和流式状态动态调整渲染策略
private struct OutputTextView: View {
    let output: String
    let isStreaming: Bool
    let targetLang: String

    // 文本长度阈值
    private let longTextThreshold = 1500

    private var isLongText: Bool {
        output.count > longTextThreshold
    }

    private var shouldDisableTextSelection: Bool {
        // 长文本流式传输时禁用textSelection以提高性能
        isLongText && isStreaming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 策略：
            // 1. 长文本流式传输中：使用 ChunkedStreamingView (LazyVStack) 保证渲染性能
            // 2. 传输完成 或 短文本：使用标准 Text 保证最佳选择体验
            // 3. 极长文本 (> 20000)：始终使用 ChunkedStreamingView 防止 Text 渲染卡死
            if (isLongText && isStreaming) || output.count > 20000 {
                ChunkedStreamingView(text: output, targetLang: targetLang)
            } else {
                if shouldDisableTextSelection {
                    Text(output)
                        .frame(maxWidth: 720, alignment: .leading)
                        .font(Typography.body)
                        .lineSpacing(Typography.lineSpacingComfortable)
                        .multilineTextAlignment(.leading)
                        .textSelection(.disabled)
                        .autoTextAlignment(for: targetLang)
                } else {
                    Text(output)
                        .frame(maxWidth: 720, alignment: .leading)
                        .font(Typography.body)
                        .lineSpacing(Typography.lineSpacingComfortable)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 1) // 微小内边距增加点击热区
                        .textSelection(.enabled)
                        .autoTextAlignment(for: targetLang)
                }
            }

            if isStreaming {
                BlinkingCursor()
                    .padding(.top, 2)
            }
        }
    }
}

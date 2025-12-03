import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var inputFocused: Bool = false
    @State private var showStreamingSpinner: Bool = false
    @State private var refocusScheduled: Bool = false
    @State private var forceFocusToken: Int = 0
    @State private var windowConfigured: Bool = false
    @State private var spinnerTask: Task<Void, Never>?
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    // MARK: - Computed Properties

    /// 窗口切换到窄模式的阈值宽度
    private var narrowModeThreshold: CGFloat {
        2 * Metrics.minPaneWidth + Metrics.splitDividerHitWidth + 2 * Metrics.outerPadding
    }

    /// 工具栏按钮的本地化文本
    private var pinButtonTexts: (help: String, label: String) {
        let isPinned = viewModel.preferences.alwaysOnTop
        let lang = viewModel.preferences.appLanguage
        return (
            help: L10n.tr(isPinned ? "toolbar.pin.on" : "toolbar.pin.off", lang: lang),
            label: L10n.tr(isPinned ? "toolbar.pin.a11y.on" : "toolbar.pin.a11y.off", lang: lang)
        )
    }

    var body: some View {
        VStack(spacing: Metrics.outerPadding) {
            TopBar(
                viewModel: viewModel,
                temporarilyBlurAndRefocus: { temporarilyBlurAndRefocus() }
            )
            .layoutPriority(1)  // 确保 TopBar 优先获取空间，不被压缩

            GeometryReader { proxy in
                let isNarrow = proxy.size.width < narrowModeThreshold

                // 根据窗口宽度选择垂直或水平布局
                Group {
                    if isNarrow {
                        narrowLayout
                    } else {
                        wideLayout(totalWidth: proxy.size.width)
                    }
                }
            }

            BottomBar(viewModel: viewModel, showStreamingSpinner: $showStreamingSpinner)
                .layoutPriority(1)  // 确保 BottomBar 优先获取空间，不被压缩
        }
        .frame(minHeight: 520)  // 设置整个视图的最小高度，防止组件被挤压
        .background(
            // 窗口背景：使用系统默认背景色以确保跨主题一致性
            AppColors.windowBackground
                .ignoresSafeArea()
        )
        .background(
            // 窗口层级适配器：必须在独立的 background 修饰符中
            WindowLevelAdapter(isAlwaysOnTop: $viewModel.isWindowAlwaysOnTop)
                .frame(width: 1, height: 1)  // 给一个极小的尺寸
                .allowsHitTesting(false)  // 不响应点击
        )
        .background(
            // 窗口尺寸配置器
            MainWindowConfigurator(configured: $windowConfigured)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .bottom) {
            if let message = viewModel.toastMessage {
                ToastView(message: message)
                    .transition(.toastSlide)
                    .padding(.bottom, 12)
            }
        }
        .animation(Animations.spring, value: viewModel.toastMessage)
        .onAppear {
            setupInitialFocus()
        }
        .onChange(of: viewModel.focusInputToken) { _, newToken in
            handleFocusTokenChange(newToken)
        }
        .onChange(of: viewModel.session.isStreaming) { _, isStreaming in
            handleStreamingStateChange(isStreaming)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showHistoryWindow() }) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonCursor()
                .help(L10n.tr("toolbar.history", lang: viewModel.preferences.appLanguage))
                .accessibilityLabel(L10n.tr("toolbar.history.a11y", lang: viewModel.preferences.appLanguage))
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.toggleAlwaysOnTop() }) {
                    Image(systemName: viewModel.preferences.alwaysOnTop ? "pin.fill" : "pin")
                }
                .buttonCursor()
                .help(pinButtonTexts.help)
                .accessibilityLabel(pinButtonTexts.label)
            }
        }
    }

}

private extension ContentView {
    // MARK: - Layout Views

    /// 窄模式布局（垂直排列）
    var narrowLayout: some View {
        VStack(spacing: Metrics.innerPadding) {
            LeftInputPane(
                viewModel: viewModel,
                inputFocused: $inputFocused,
                forceFocusToken: forceFocusToken
            )
            AppColors.divider
                .frame(height: 1)
            RightOutputPane(viewModel: viewModel)
        }
    }

    /// 宽模式布局（水平双面板）
    func wideLayout(totalWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            let dividerThickness: CGFloat = 1
            let paneWidth = max(Metrics.minPaneWidth, (totalWidth - dividerThickness) / 2)

            LeftInputPane(
                viewModel: viewModel,
                inputFocused: $inputFocused,
                forceFocusToken: forceFocusToken
            )
            .frame(width: paneWidth)

            AppColors.divider
                .frame(width: dividerThickness)

            RightOutputPane(viewModel: viewModel)
                .frame(width: paneWidth)
        }
    }

    // MARK: - Lifecycle Methods

    /// 设置初始焦点状态
    func setupInitialFocus() {
        inputFocused = true
        // 延迟设置焦点 token，确保窗口已完全初始化
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            forceFocusToken = -1  // 使用负数 token 表示初始焦点
        }
    }

    /// 处理焦点 token 变化
    func handleFocusTokenChange(_ newToken: Int) {
        forceFocusToken = newToken
        inputFocused = true
    }

    /// 处理流式传输状态变化
    func handleStreamingStateChange(_ isStreaming: Bool) {
        // 取消之前的延迟任务
        spinnerTask?.cancel()

        if isStreaming {
            showStreamingSpinner = false
            // 延迟显示 spinner，避免闪烁
            spinnerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 秒
                // 再次检查状态，避免任务执行时已停止流式传输
                if viewModel.session.isStreaming {
                    showStreamingSpinner = true
                }
            }
        } else {
            showStreamingSpinner = false
        }
    }

    /// 临时失焦后重新聚焦（用于提供视觉反馈）
    func temporarilyBlurAndRefocus(after delay: TimeInterval = 0.25) {
        guard !refocusScheduled else { return }
        refocusScheduled = true

        inputFocused = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            inputFocused = true
            refocusScheduled = false
        }
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .calloutStyle()
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.toastMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppColors.borderNormal, lineWidth: 0.5)
            }
            .shadow(color: AppColors.toastShadow, radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: AppViewModel())
            .frame(width: 900, height: 600)
    }
}

// MARK: - 主窗口尺寸配置器
private struct MainWindowConfigurator: NSViewRepresentable {
    @Binding var configured: Bool

    // MARK: - 配置常量
    private enum WindowConfig {
        static let minWidth: CGFloat = 750
        static let minHeight: CGFloat = 520
        static let defaultWidth: CGFloat = 800
        static let defaultHeight: CGFloat = 560
        static let maxWidth: CGFloat = 1200
        static let maxHeight: CGFloat = 800
        static let widthRatio: CGFloat = 0.55
        static let heightRatio: CGFloat = 0.60
    }

    func makeNSView(context: Context) -> ConfiguratorView {
        let view = ConfiguratorView()
        view.onWindowAttached = { [self] window in
            self.configureWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: ConfiguratorView, context: Context) {
        // 响应式配置：如果窗口配置状态发生变化，可以在这里处理
    }

    /// 配置窗口的尺寸和位置
    private func configureWindow(_ window: NSWindow) {
        guard !configured else { return }

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        guard visibleFrame != .zero else { return }

        // 计算目标尺寸（基于屏幕大小，带最小和最大限制）
        let targetSize = calculateTargetSize(for: visibleFrame)

        // 应用窗口配置
        window.setContentSize(targetSize)
        window.minSize = NSSize(width: WindowConfig.minWidth, height: WindowConfig.minHeight)
        window.center()

        configured = true
    }

    /// 根据屏幕可视区域计算合适的窗口尺寸
    private func calculateTargetSize(for visibleFrame: NSRect) -> NSSize {
        let width = min(
            max(WindowConfig.defaultWidth, visibleFrame.width * WindowConfig.widthRatio),
            WindowConfig.maxWidth
        )
        let height = min(
            max(WindowConfig.defaultHeight, visibleFrame.height * WindowConfig.heightRatio),
            WindowConfig.maxHeight
        )
        return NSSize(width: width, height: height)
    }

    /// 自定义 NSView，用于监听窗口附加事件
    final class ConfiguratorView: NSView {
        var onWindowAttached: ((NSWindow) -> Void)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = window {
                onWindowAttached?(window)
            }
        }
    }
}

struct BlinkingCursor: View {
    @State private var visible: Bool = true

    var body: some View {
        Text("▍")
            .foregroundColor(AppColors.placeholder)
            .opacity(visible ? 1.0 : 0.3)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                ) {
                    visible.toggle()
                }
            }
    }
}

// BackgroundClickMonitor removed: refocus is controlled explicitly by UI actions

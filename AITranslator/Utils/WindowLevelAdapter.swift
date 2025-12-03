import SwiftUI
import AppKit

/// 主窗口层级适配器
/// 根据绑定的状态动态调整窗口层级，实现置顶功能
/// 使用统一的 WindowLevelManager 管理层级关系
struct WindowLevelAdapter: NSViewRepresentable {
    @Binding var isAlwaysOnTop: Bool

    func makeNSView(context: Context) -> HelperView {
        let view = HelperView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear

        // 设置窗口变化回调
        view.onWindowChanged = { [self] window in
            self.applyWindowLevel(to: window)
        }

        // 如果窗口已经可用，立即应用设置
        if let window = view.window {
            applyWindowLevel(to: window)
        }

        return view
    }

    func updateNSView(_ nsView: HelperView, context: Context) {
        // 只在窗口可用且层级需要改变时才更新
        guard let window = nsView.window else { return }

        let targetLevel = isAlwaysOnTop ? WindowLevelManager.Level.floating : WindowLevelManager.Level.normal
        guard window.level != targetLevel else { return }

        applyWindowLevel(to: window)
    }

    /// 辅助视图类，用于监听窗口附加事件
    final class HelperView: NSView {
        var onWindowChanged: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = window {
                onWindowChanged?(window)
            }
        }
    }

    /// 应用窗口层级设置
    private func applyWindowLevel(to window: NSWindow) {
        // 通知 WindowLevelManager 更新主窗口状态
        Task { @MainActor in
            WindowLevelManager.shared.setMainWindowAlwaysOnTop(isAlwaysOnTop)
        }

        // 使用统一的窗口配置方法
        Task { @MainActor in
            WindowLevelManager.shared.configureMainWindow(window, isAlwaysOnTop: isAlwaysOnTop)
        }
    }
}

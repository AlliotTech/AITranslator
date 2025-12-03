import SwiftUI
import AppKit
import Combine

/// 设置窗口层级适配器
/// 确保设置窗口总是显示在主窗口之上，即使主窗口被置顶
/// 使用统一的 WindowLevelManager 动态调整层级
struct SettingsWindowLevelAdapter: NSViewRepresentable {
    func makeNSView(context: Context) -> HelperView {
        let view = HelperView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear

        // 设置窗口变化回调
        view.onWindowChanged = { window in
            self.applyWindowLevel(to: window)
        }

        // 如果窗口已经可用，立即应用设置
        if let window = view.window {
            applyWindowLevel(to: window)
        }

        return view
    }

    func updateNSView(_ nsView: HelperView, context: Context) {
        // 定期检查并更新窗口层级（因为主窗口置顶状态可能改变）
        guard let window = nsView.window else { return }

        let expectedLevel = WindowLevelManager.shared.auxiliaryWindowLevel()
        guard window.level != expectedLevel else { return }

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
        Task { @MainActor in
            // 注册为辅助窗口
            WindowLevelManager.shared.registerAuxiliaryWindow(window)

            // 使用统一的窗口配置方法
            WindowLevelManager.shared.configureAuxiliaryWindow(window)
        }
    }
}

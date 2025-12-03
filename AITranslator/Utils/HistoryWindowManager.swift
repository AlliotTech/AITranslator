import Foundation
import SwiftUI
import AppKit

/// 历史记录窗口管理器
/// 负责创建、显示和管理历史记录窗口的生命周期
@MainActor
final class HistoryWindowManager {
    /// 历史记录窗口实例
    private var window: NSWindow?

    /// 显示历史记录窗口
    /// 如果窗口已存在，则将其置于前台；否则创建新窗口
    /// - Parameters:
    ///   - historyManager: 历史记录管理器
    ///   - preferences: 用户偏好设置
    func show(historyManager: HistoryManager, preferences: Preferences) {
        // 如果窗口已存在且可见，更新层级并置于前台
        if let window = window, window.isVisible {
            // 确保窗口层级正确（可能主窗口置顶状态已改变）
            WindowLevelManager.shared.configureAuxiliaryWindow(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 创建历史记录视图
        let historyView = HistoryWindow(
            historyManager: historyManager,
            preferences: preferences
        )

        // 创建窗口
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // 设置窗口标题
        let title = preferences.appLanguage == .zhHans ? "历史记录" : "History"
        newWindow.title = title

        // 设置最小尺寸
        newWindow.minSize = NSSize(width: 800, height: 600)

        // 居中显示
        newWindow.center()

        // 设置内容视图
        newWindow.contentView = NSHostingView(rootView: historyView)

        // 设置窗口关闭时的处理
        newWindow.isReleasedWhenClosed = false

        // 注册为辅助窗口并配置层级
        WindowLevelManager.shared.registerAuxiliaryWindow(newWindow)
        WindowLevelManager.shared.configureAuxiliaryWindow(newWindow)

        // 显示窗口
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 保存窗口引用
        self.window = newWindow
    }

    /// 关闭历史记录窗口
    func close() {
        // 注销窗口
        if let window = window {
            WindowLevelManager.shared.unregisterAuxiliaryWindow(window)
        }
        window?.close()
        window = nil
    }

    /// 检查窗口是否可见
    var isVisible: Bool {
        window?.isVisible ?? false
    }
}

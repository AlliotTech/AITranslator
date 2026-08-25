import AppKit

/// 主窗口展示控制
///
/// 把 NSApp / NSWindow 操作从 ViewModel 里隔离出来，便于测试与替换。
@MainActor
protocol WindowPresenting {
    /// 切换主窗口显示/隐藏（不影响设置、历史等辅助窗口）
    /// - Returns: true 表示本次是「显示」，false 表示本次是「隐藏」
    @discardableResult
    func toggleMainWindow() -> Bool
}

/// 基于 AppKit 的默认实现
@MainActor
final class AppKitWindowPresenter: WindowPresenting {
    @discardableResult
    func toggleMainWindow() -> Bool {
        // 获取主窗口（排除辅助窗口如设置窗口、历史记录窗口）
        let mainWindow = WindowLevelManager.shared.getMainWindow()

        // 检查主窗口是否可见
        let isMainWindowVisible = mainWindow?.isVisible == true && mainWindow?.isMiniaturized == false

        if NSApp.isHidden == false && NSApp.isActive && isMainWindowVisible {
            // 隐藏主窗口
            // 注意：只隐藏主窗口，不影响辅助窗口（设置、历史记录等）
            mainWindow?.orderOut(nil)
            return false
        }

        // 显示主窗口
        if let window = mainWindow {
            if window.isMiniaturized {
                // 如果主窗口被最小化到 Dock，先恢复
                if NSApp.isHidden { NSApp.unhide(nil) }
                window.deminiaturize(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // 显示主窗口
                if NSApp.isHidden { NSApp.unhide(nil) }
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            // 主窗口引用不存在，尝试查找第一个非辅助窗口
            // 这是一个备用方案，正常情况下不应该执行到这里
            if let firstWindow = NSApp.windows.first(where: { window in
                window.canBecomeKey && !WindowLevelManager.shared.isAuxiliaryWindow(window)
            }) {
                if NSApp.isHidden { NSApp.unhide(nil) }
                firstWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // 最后的备用方案：只激活应用
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        return true
    }
}

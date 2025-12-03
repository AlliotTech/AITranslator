import AppKit
import Foundation

/// 窗口层级管理器
/// 统一管理应用内所有窗口的层级关系，确保窗口显示顺序正确
@MainActor
final class WindowLevelManager {
    /// 单例实例
    static let shared = WindowLevelManager()

    /// 主窗口是否置顶
    private(set) var isMainWindowAlwaysOnTop: Bool = false

    /// 主窗口引用（弱引用）
    private weak var mainWindow: NSWindow?

    /// 注册的辅助窗口（设置窗口、历史记录窗口等）
    /// 使用 WeakReference 避免循环引用
    private var auxiliaryWindows: [WeakWindowReference] = []

    private init() {}

    // MARK: - Window Level Constants

    /// 窗口层级常量
    /// 定义应用内使用的各种窗口层级及其用途
    enum Level {
        /// 普通层级 (0) - 用于未置顶的主窗口
        static let normal: NSWindow.Level = .normal

        /// 浮动层级 (3) - 用于置顶的主窗口
        static let floating: NSWindow.Level = .floating

        /// 辅助面板层级 (8) - 用于需要显示在置顶主窗口之上的辅助窗口
        /// 包括设置窗口、历史记录窗口等
        static let auxiliary: NSWindow.Level = .modalPanel
    }

    // MARK: - Main Window Management

    /// 更新主窗口的置顶状态
    /// 同时更新所有已注册的辅助窗口的层级
    /// - Parameter isAlwaysOnTop: 主窗口是否置顶
    func setMainWindowAlwaysOnTop(_ isAlwaysOnTop: Bool) {
        guard self.isMainWindowAlwaysOnTop != isAlwaysOnTop else { return }

        self.isMainWindowAlwaysOnTop = isAlwaysOnTop

        // 更新所有辅助窗口的层级
        updateAllAuxiliaryWindows()
    }

    /// 获取主窗口应该使用的层级
    /// - Returns: 窗口层级
    func mainWindowLevel() -> NSWindow.Level {
        return isMainWindowAlwaysOnTop ? Level.floating : Level.normal
    }

    // MARK: - Auxiliary Window Management

    /// 注册辅助窗口
    /// 辅助窗口（如设置窗口、历史记录窗口）会根据主窗口的置顶状态自动调整层级
    /// - Parameter window: 要注册的窗口
    func registerAuxiliaryWindow(_ window: NSWindow) {
        // 移除已经释放的窗口引用
        cleanupReleasedWindows()

        // 检查是否已注册
        if auxiliaryWindows.contains(where: { $0.window === window }) {
            return
        }

        // 添加到注册列表
        auxiliaryWindows.append(WeakWindowReference(window: window))

        // 立即应用正确的层级
        applyAuxiliaryLevel(to: window)
    }

    /// 注销辅助窗口
    /// - Parameter window: 要注销的窗口
    func unregisterAuxiliaryWindow(_ window: NSWindow) {
        auxiliaryWindows.removeAll { $0.window === window || $0.window == nil }
    }

    /// 获取辅助窗口应该使用的层级
    /// - Returns: 窗口层级
    func auxiliaryWindowLevel() -> NSWindow.Level {
        // 辅助窗口需要根据主窗口状态决定层级：
        // - 如果主窗口置顶（floating），辅助窗口需要更高层级（auxiliary）才能显示在主窗口之上
        // - 如果主窗口未置顶（normal），辅助窗口也使用普通层级（normal）即可
        return isMainWindowAlwaysOnTop ? Level.auxiliary : Level.normal
    }

    // MARK: - Window Configuration

    /// 配置主窗口的层级和行为
    /// - Parameters:
    ///   - window: 要配置的窗口
    ///   - isAlwaysOnTop: 是否置顶
    func configureMainWindow(_ window: NSWindow, isAlwaysOnTop: Bool) {
        // 注册主窗口引用
        if mainWindow !== window {
            mainWindow = window
        }

        let targetLevel = isAlwaysOnTop ? Level.floating : Level.normal

        // 调整窗口行为以更好地集成 Spaces 和全屏模式
        if isAlwaysOnTop {
            // 置顶窗口设置为全屏辅助窗口，可以在全屏应用上显示
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            // 允许窗口在所有 Spaces 中显示（可选，根据用户需求）
            window.collectionBehavior.insert(.canJoinAllSpaces)
        } else {
            window.collectionBehavior.remove(.fullScreenAuxiliary)
            window.collectionBehavior.remove(.canJoinAllSpaces)
        }

        // 确保窗口不会在失去焦点时自动隐藏
        window.hidesOnDeactivate = false

        // 设置窗口层级
        window.level = targetLevel

        // 关键步骤：调用 orderFront 系列方法触发窗口管理器重新评估窗口顺序
        // 仅设置 window.level 属性不会立即生效，必须配合窗口排序方法
        if window.isVisible {
            if isAlwaysOnTop {
                // 置顶：使用 orderFrontRegardless 强制窗口显示在新层级
                window.orderFrontRegardless()
            } else {
                // 取消置顶：使用 orderFront 将窗口放到普通层级的前面
                window.orderFront(nil)
            }
        }
    }

    /// 获取主窗口引用
    /// - Returns: 主窗口，如果不存在则返回 nil
    func getMainWindow() -> NSWindow? {
        return mainWindow
    }

    /// 判断窗口是否为辅助窗口
    /// - Parameter window: 要判断的窗口
    /// - Returns: 是否为辅助窗口
    func isAuxiliaryWindow(_ window: NSWindow) -> Bool {
        return auxiliaryWindows.contains(where: { $0.window === window })
    }

    /// 配置辅助窗口的层级和行为
    /// - Parameter window: 要配置的窗口
    func configureAuxiliaryWindow(_ window: NSWindow) {
        applyAuxiliaryLevel(to: window)
    }

    // MARK: - Private Methods

    /// 应用辅助窗口层级
    private func applyAuxiliaryLevel(to window: NSWindow) {
        let targetLevel = auxiliaryWindowLevel()

        // 确保窗口不会在失去焦点时自动隐藏
        window.hidesOnDeactivate = false

        // 设置窗口层级
        window.level = targetLevel

        // 触发窗口管理器重新评估窗口顺序
        if window.isVisible {
            window.orderFrontRegardless()
        }
    }

    /// 更新所有已注册的辅助窗口层级
    private func updateAllAuxiliaryWindows() {
        cleanupReleasedWindows()

        for ref in auxiliaryWindows {
            if let window = ref.window {
                applyAuxiliaryLevel(to: window)
            }
        }
    }

    /// 清理已释放的窗口引用
    private func cleanupReleasedWindows() {
        auxiliaryWindows.removeAll { $0.window == nil }
    }
}

// MARK: - Weak Window Reference

/// 弱引用窗口包装器
/// 避免 WindowLevelManager 强引用窗口导致内存泄漏
private class WeakWindowReference {
    weak var window: NSWindow?

    init(window: NSWindow) {
        self.window = window
    }
}

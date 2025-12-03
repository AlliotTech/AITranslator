import SwiftUI

/// macOS风格的颜色系统
/// 遵循Apple Human Interface Guidelines，支持深色/浅色模式自适应
enum AppColors {
    // MARK: - 面板背景

    /// 主要面板背景材质（毛玻璃效果）
    static let paneMaterial: Material = .thinMaterial

    /// Toast提示背景材质
    static let toastMaterial: Material = .ultraThinMaterial

    // MARK: - 边框颜色

    /// 普通状态边框颜色
    static let borderNormal = Color.primary.opacity(0.08)

    /// 焦点状态边框颜色
    static let borderFocused = Color.accentColor.opacity(0.6)

    /// 无障碍模式下的普通边框
    static let borderNormalA11y = Color.primary.opacity(0.25)

    /// 无障碍模式下的焦点边框
    static let borderFocusedA11y = Color.accentColor

    // MARK: - 阴影

    /// 面板阴影颜色
    static let paneShadow = Color.black.opacity(0.08)

    /// Toast阴影颜色
    static let toastShadow = Color.black.opacity(0.12)

    /// 按钮阴影颜色
    static let buttonShadow = Color.black.opacity(0.05)

    // MARK: - 分隔线

    /// 分隔线颜色（自适应系统样式）
    static let divider = Color(nsColor: .separatorColor)

    // MARK: - 按钮覆盖层

    /// 按钮悬停状态覆盖层
    static let buttonHoverOverlay = Color.primary.opacity(0.06)

    /// 按钮按下状态覆盖层
    static let buttonPressOverlay = Color.primary.opacity(0.12)

    /// 按钮禁用状态覆盖层
    static let buttonDisabledOverlay = Color.primary.opacity(0.03)

    // MARK: - 文本颜色

    /// 占位符文本颜色
    static let placeholder = Color.secondary.opacity(0.6)

    /// 错误文本颜色
    static let error = Color.red.opacity(0.9)

    /// 成功提示颜色
    static let success = Color.green.opacity(0.9)

    // MARK: - 背景色

    /// 窗口背景色（系统原生）
    static let windowBackground = Color(nsColor: .windowBackgroundColor)

    /// 内容背景色（稍微深一点的背景）
    static let contentBackground = Color(nsColor: .controlBackgroundColor)
}

// MARK: - 视觉效果扩展

extension View {
    /// 应用标准面板样式（包含背景、边框、阴影）
    func paneStyle(isFocused: Bool = false, differentiateWithoutColor: Bool = false) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: Metrics.paneCornerRadius, style: .continuous)
                    .fill(AppColors.paneMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.paneCornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused
                            ? (differentiateWithoutColor ? AppColors.borderFocusedA11y : AppColors.borderFocused)
                            : (differentiateWithoutColor ? AppColors.borderNormalA11y : AppColors.borderNormal),
                        lineWidth: isFocused ? 2 : 1
                    )
            }
            .shadow(
                color: AppColors.paneShadow,
                radius: isFocused ? 8 : 4,
                x: 0,
                y: isFocused ? 3 : 2
            )
            .animation(Animations.standard, value: isFocused)
    }

    /// 应用卡片样式（更微妙的效果）
    func cardStyle() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.contentBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(AppColors.borderNormal, lineWidth: 0.5)
            }
            .shadow(color: AppColors.paneShadow, radius: 2, x: 0, y: 1)
    }
}

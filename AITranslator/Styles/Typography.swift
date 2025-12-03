import SwiftUI

/// macOS 风格的字体排版系统
/// 遵循 Apple Human Interface Guidelines，提供清晰的视觉层级
enum Typography {
    // MARK: - 字体样式

    /// 大标题 - 用于主要标题
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)

    /// 标题1 - 用于节标题
    static let title = Font.system(.title, design: .default, weight: .semibold)

    /// 标题2 - 用于子标题
    static let title2 = Font.system(.title2, design: .default, weight: .semibold)

    /// 标题3 - 用于小标题
    static let title3 = Font.system(.title3, design: .default, weight: .semibold)

    /// 标题（设置界面专用）
    static let headline = Font.system(.headline, design: .default, weight: .semibold)

    /// 子标题
    static let subheadline = Font.system(.subheadline, design: .default, weight: .medium)

    /// 正文 - 默认文本
    static let body = Font.system(.body, design: .default, weight: .regular)

    /// 正文（强调）
    static let bodyEmphasized = Font.system(.body, design: .default, weight: .medium)

    /// 标注 - 次要说明文本
    static let callout = Font.system(.callout, design: .default, weight: .regular)

    /// 脚注 - 辅助信息
    static let footnote = Font.system(.footnote, design: .default, weight: .regular)

    /// 说明文字 - 最小文本
    static let caption = Font.system(.caption, design: .default, weight: .regular)

    /// 说明文字2 - 更小的辅助文本
    static let caption2 = Font.system(.caption2, design: .default, weight: .regular)

    // MARK: - 等宽字体（用于代码、API Key等）

    /// 等宽正文
    static let monoBody = Font.system(.body, design: .monospaced, weight: .regular)

    /// 等宽脚注
    static let monoFootnote = Font.system(.footnote, design: .monospaced, weight: .regular)

    // MARK: - 行距设置

    /// 紧凑行距 - 用于标题
    static let lineSpacingTight: CGFloat = 2

    /// 标准行距 - 用于正文
    static let lineSpacingNormal: CGFloat = 4

    /// 舒适行距 - 用于长文本阅读
    static let lineSpacingComfortable: CGFloat = 6

    /// 宽松行距 - 用于特殊场景
    static let lineSpacingRelaxed: CGFloat = 8

    // MARK: - 段落间距

    /// 小段落间距
    static let paragraphSpacingSmall: CGFloat = 8

    /// 标准段落间距
    static let paragraphSpacingNormal: CGFloat = 12

    /// 大段落间距
    static let paragraphSpacingLarge: CGFloat = 16
}

// MARK: - 文本样式修饰器

extension View {
    /// 应用大标题样式
    func largeTitleStyle() -> some View {
        self
            .font(Typography.largeTitle)
            .lineSpacing(Typography.lineSpacingTight)
    }

    /// 应用标题样式
    func titleStyle() -> some View {
        self
            .font(Typography.title)
            .lineSpacing(Typography.lineSpacingTight)
    }

    /// 应用标题2样式
    func title2Style() -> some View {
        self
            .font(Typography.title2)
            .lineSpacing(Typography.lineSpacingTight)
    }

    /// 应用标题3样式
    func title3Style() -> some View {
        self
            .font(Typography.title3)
            .lineSpacing(Typography.lineSpacingTight)
    }

    /// 应用标题样式（设置界面专用）
    func headlineStyle() -> some View {
        self
            .font(Typography.headline)
            .lineSpacing(Typography.lineSpacingTight)
    }

    /// 应用子标题样式
    func subheadlineStyle() -> some View {
        self
            .font(Typography.subheadline)
            .lineSpacing(Typography.lineSpacingNormal)
    }

    /// 应用正文样式（舒适行距，适合长文本阅读）
    func bodyStyle(comfortable: Bool = true) -> some View {
        self
            .font(Typography.body)
            .lineSpacing(comfortable ? Typography.lineSpacingComfortable : Typography.lineSpacingNormal)
    }

    /// 应用强调正文样式
    func bodyEmphasizedStyle() -> some View {
        self
            .font(Typography.bodyEmphasized)
            .lineSpacing(Typography.lineSpacingNormal)
    }

    /// 应用标注样式
    func calloutStyle() -> some View {
        self
            .font(Typography.callout)
            .lineSpacing(Typography.lineSpacingNormal)
    }

    /// 应用脚注样式
    func footnoteStyle() -> some View {
        self
            .font(Typography.footnote)
            .lineSpacing(Typography.lineSpacingNormal)
    }

    /// 应用说明文字样式
    func captionStyle() -> some View {
        self
            .font(Typography.caption)
            .lineSpacing(Typography.lineSpacingTight)
    }

    /// 应用等宽正文样式（用于API Key、URL等）
    func monoBodyStyle() -> some View {
        self
            .font(Typography.monoBody)
            .lineSpacing(Typography.lineSpacingNormal)
    }

    /// 应用等宽脚注样式
    func monoFootnoteStyle() -> some View {
        self
            .font(Typography.monoFootnote)
            .lineSpacing(Typography.lineSpacingNormal)
    }
}

// MARK: - 文本对齐辅助

extension View {
    /// 根据语言代码自动设置文本对齐方向
    func autoTextAlignment(for languageCode: String) -> some View {
        self.environment(\.layoutDirection,
                        LanguageUtils.isRTLLanguage(code: languageCode) ? .rightToLeft : .leftToRight)
    }
}

// MARK: - 段落样式

extension Text {
    /// 应用段落样式
    func paragraphStyle(spacing: CGFloat = Typography.paragraphSpacingNormal) -> some View {
        self.padding(.bottom, spacing)
    }
}

// MARK: - 辅助功能优化

extension View {
    /// 支持动态字体大小（辅助功能）
    /// 限制动态字体大小范围，避免字体过大或过小影响布局
    func dynamicTypeSupport(minSize: DynamicTypeSize = .xSmall, maxSize: DynamicTypeSize = .xxxLarge) -> some View {
        self.dynamicTypeSize(minSize...maxSize)
    }
}

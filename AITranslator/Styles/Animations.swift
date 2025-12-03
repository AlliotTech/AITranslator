import SwiftUI

/// 统一的动画效果系统
/// 提供一致的微交互动画，提升用户体验
enum Animations {
    // MARK: - 动画曲线

    /// 快速响应动画（按钮点击等）
    static let quickResponse = Animation.easeOut(duration: 0.15)

    /// 标准过渡动画（状态切换等）
    static let standard = Animation.easeInOut(duration: 0.25)

    /// 平滑过渡动画（大型布局变化）
    static let smooth = Animation.easeInOut(duration: 0.35)

    /// 弹性动画（成功反馈等）
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)

    /// 柔和弹性动画（微妙的反馈）
    static let gentleSpring = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)

    /// 强烈弹性动画（重要反馈）
    static let bouncySpring = Animation.spring(response: 0.25, dampingFraction: 0.6, blendDuration: 0)

    // MARK: - 动画参数

    /// 按钮点击缩放比例
    static let buttonPressScale: CGFloat = 0.95

    /// 图标旋转角度
    static let iconRotation: Angle = .degrees(180)

    /// Toast滑入距离
    static let toastSlideDistance: CGFloat = 20

    /// 抖动幅度
    static let shakeOffset: CGFloat = 8
}

// MARK: - 动画修饰器

extension View {
    /// 按钮点击缩放效果
    func buttonPressEffect(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? Animations.buttonPressScale : 1.0)
            .animation(Animations.quickResponse, value: isPressed)
    }

    /// 旋转动画效果
    func rotationEffect(isRotated: Bool, angle: Angle = Animations.iconRotation) -> some View {
        self.rotationEffect(isRotated ? angle : .zero)
            .animation(Animations.spring, value: isRotated)
    }

    /// 抖动动画（用于错误提示）
    func shake(trigger: Int) -> some View {
        self.modifier(ShakeEffect(shakes: trigger))
    }

    /// 淡入淡出效果
    func fadeTransition(isVisible: Bool) -> some View {
        self.opacity(isVisible ? 1 : 0)
            .animation(Animations.standard, value: isVisible)
    }

    /// 缩放淡入效果
    func scaleAndFadeIn(isVisible: Bool) -> some View {
        self
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .animation(Animations.spring, value: isVisible)
    }

    /// 成功反馈动画（带弹性）
    func successPulse(isActive: Bool) -> some View {
        self
            .scaleEffect(isActive ? 1.1 : 1.0)
            .opacity(isActive ? 1.0 : 0.8)
            .animation(Animations.bouncySpring, value: isActive)
    }
}

// MARK: - 抖动效果

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = Animations.shakeOffset * sin(animatableData * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

// MARK: - 自定义过渡效果

extension AnyTransition {
    /// Toast 滑入效果
    static var toastSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        )
    }

    /// 从中心缩放淡入
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }

    /// 柔和的淡入淡出
    static var gentleFade: AnyTransition {
        .opacity.animation(Animations.smooth)
    }
}

// MARK: - 按钮样式（带动画）

struct AnimatedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Animations.buttonPressScale : 1.0)
            .animation(Animations.quickResponse, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AnimatedButtonStyle {
    static var animated: AnimatedButtonStyle { AnimatedButtonStyle() }
}

// MARK: - 加载动画

struct PulsingDot: View {
    @State private var isPulsing = false
    let delay: Double

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.2 : 0.8)
            .opacity(isPulsing ? 1.0 : 0.4)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

struct LoadingDots: View {
    var body: some View {
        HStack(spacing: 6) {
            PulsingDot(delay: 0)
            PulsingDot(delay: 0.2)
            PulsingDot(delay: 0.4)
        }
    }
}

// MARK: - 成功标记动画

struct SuccessCheckmark: View {
    @State private var drawPath = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(AppColors.success)
            .scaleEffect(drawPath ? 1.0 : 0.5)
            .opacity(drawPath ? 1.0 : 0.0)
            .onAppear {
                withAnimation(Animations.bouncySpring) {
                    drawPath = true
                }
            }
    }
}

// MARK: - 错误标记动画

struct ErrorIcon: View {
    @State private var shakeCount = 0

    var body: some View {
        Image(systemName: "xmark.circle.fill")
            .foregroundColor(AppColors.error)
            .shake(trigger: shakeCount)
            .onAppear {
                withAnimation(Animations.quickResponse) {
                    shakeCount += 1
                }
            }
    }
}

// MARK: - 提示气泡动画

struct TooltipBubble: View {
    let text: String
    @State private var isVisible = false

    var body: some View {
        Text(text)
            .footnoteStyle()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppColors.toastMaterial)
                    .shadow(color: AppColors.toastShadow, radius: 8, x: 0, y: 2)
            }
            .scaleAndFadeIn(isVisible: isVisible)
            .onAppear {
                withAnimation(Animations.spring.delay(0.1)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - 骨架屏效果

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}

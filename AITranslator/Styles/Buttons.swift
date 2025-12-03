import SwiftUI
import AppKit

// Primary action button modifier: consistent prominent style and size.
struct PrimaryProminentButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .buttonCursor()
    }
}

// Secondary action button modifier: bordered and small size for tool-like actions.
struct SecondaryBorderedButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.bordered)
            .controlSize(.small)
            .buttonCursor()
    }
}

// Overlay icon button: larger hit target with subtle hover/press material.
struct OverlayIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OverlayIconButton(configuration: configuration)
    }

    private struct OverlayIconButton: View {
        let configuration: Configuration
        @State private var isHovering: Bool = false

        var body: some View {
            configuration.label
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.paneMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            configuration.isPressed
                                ? AppColors.buttonPressOverlay
                                : (isHovering ? AppColors.buttonHoverOverlay : Color.clear)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(AppColors.borderNormal, lineWidth: 0.5)
                }
                .shadow(
                    color: AppColors.buttonShadow,
                    radius: isHovering ? 3 : 1,
                    x: 0,
                    y: isHovering ? 2 : 1
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onHover { hovering in
                    isHovering = hovering
                    // 设置手型光标
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .animation(Animations.standard, value: isHovering)
                .animation(Animations.quickResponse, value: configuration.isPressed)
        }
    }
}

// Button cursor modifier: 为按钮添加手型光标效果
struct ButtonCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                // 只有在按钮启用时才显示手型光标
                if isEnabled {
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
    }
}

extension View {
    func primaryProminentButton() -> some View {
        self.modifier(PrimaryProminentButtonModifier())
    }

    func secondaryBorderedButton() -> some View {
        self.modifier(SecondaryBorderedButtonModifier())
    }

    /// 为按钮添加手型光标效果
    func buttonCursor() -> some View {
        self.modifier(ButtonCursorModifier())
    }
}

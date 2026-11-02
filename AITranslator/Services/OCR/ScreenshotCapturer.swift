import AppKit
import Foundation
import ScreenCaptureKit

/// 截图选区捕获错误
enum ScreenshotCaptureError: Error {
    case screenRecordingPermissionDenied
    case noDisplay
    case cancelled
}

/// 截图选取与捕获。
///
/// 流程：预检屏幕录制权限 → ScreenCaptureKit 截取鼠标所在显示器整屏 →
/// 全屏覆盖层上拖拽选区 → 按选区裁剪出 CGImage。
///
/// 使用 ScreenCaptureKit（而非 `screencapture` CLI）：App Sandbox 下子进程
/// 无法通过窗口服务捕获，而 SCScreenshotManager 与沙盒兼容。
@MainActor
final class ScreenshotCapturer {
    static let shared = ScreenshotCapturer()

    private var activeOverlay: SelectionOverlayWindow?
    /// 关闭正在显示的选区覆盖层（用于取消进行中的截图）

    func cancelPending() {
        activeOverlay?.forceCancel()
        activeOverlay = nil
    }

    func captureSelection() async throws -> CGImage {
        // 重复触发时先关闭上一次的覆盖层
        activeOverlay?.forceCancel()
        activeOverlay = nil

        // 权限预检：未授权时触发系统授权弹窗，但本次无法捕获
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            throw ScreenshotCaptureError.screenRecordingPermissionDenied
        }

        // 鼠标所在的显示器
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let screenFrame = targetScreen?.frame,
            let displayID = targetScreen?.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID else {
            throw ScreenshotCaptureError.noDisplay
        }

        let shareable = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = shareable.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenshotCaptureError.noDisplay
        }

        // 按物理像素截取整屏，保证小字号文字的识别精度
        let pixelWidth = CGDisplayPixelsWide(displayID)
        let pixelHeight = CGDisplayPixelsHigh(displayID)
        let config = SCStreamConfiguration()
        config.width = pixelWidth
        config.height = pixelHeight
        config.showsCursor = false
        config.captureResolution = .best

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        // 覆盖层选区；Esc 或纯点击（无拖拽）为取消
        let overlay = SelectionOverlayWindow(screenFrame: screenFrame, screenshot: fullImage)
        activeOverlay = overlay
        defer { activeOverlay = nil }

        let selection = await overlay.runAndAwaitSelection()
        guard let selection, selection.width > 4, selection.height > 4 else {
            throw ScreenshotCaptureError.cancelled
        }

        // 选区是覆盖层窗口的本地坐标（窗口 frame 即所在屏幕 frame）→ 图像像素
        let scaleX = CGFloat(pixelWidth) / screenFrame.width
        let scaleY = CGFloat(pixelHeight) / screenFrame.height
        let cropRect = CGRect(
            x: selection.minX * scaleX,
            y: (screenFrame.height - selection.maxY) * scaleY, // 窗口左下原点 → 图像左上原点
            width: selection.width * scaleX,
            height: selection.height * scaleY
        ).integral
            .intersection(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard cropRect.width >= 1, cropRect.height >= 1,
            let cropped = fullImage.cropping(to: cropRect) else {
            throw ScreenshotCaptureError.cancelled
        }
        return cropped
    }
}

// MARK: - Overlay window & view

private final class SelectionOverlayWindow: NSWindow {
    private var finishHandler: ((NSRect?) -> Void)?

    init(screenFrame: NSRect, screenshot: CGImage) {
        super.init(contentRect: screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = SelectionOverlayView(screenshot: screenshot, screenFrame: screenFrame) { [weak self] rect in
            self?.finishHandler?(rect)
            self?.orderOut(nil)
        }
        self.contentView = contentView
        makeKeyAndOrderFront(nil)
        makeFirstResponder(contentView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func runAndAwaitSelection() async -> NSRect? {
        await withCheckedContinuation { continuation in
            finishHandler = { rect in
                continuation.resume(returning: rect)
            }
        }
    }

    /// 关闭覆盖层并以取消结束等待
    func forceCancel() {
        finishHandler?(nil)
    }
}

private final class SelectionOverlayView: NSView {
    private let screenshot: CGImage
    private var dragStart: NSPoint?
    private var dragCurrent: NSPoint?

    private let onFinish: (NSRect?) -> Void

    init(screenshot: CGImage, screenFrame: NSRect, onFinish: @escaping (NSRect?) -> Void) {
        self.screenshot = screenshot
        self.onFinish = onFinish
        super.init(frame: screenFrame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 整屏截图铺满，再整体压暗一层
        ctx.draw(screenshot, in: bounds)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.25).cgColor)
        ctx.fill(bounds)

        guard let start = dragStart, let current = dragCurrent else { return }
        let rect = Self.selectionRect(from: start, to: current)
        // 选区内恢复原始亮度：裁剪后重绘未压暗的原图
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.draw(screenshot, in: bounds)
        ctx.restoreGState()
        // 选区边框
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(rect)
    }

    private static func selectionRect(from start: NSPoint, to current: NSPoint) -> NSRect {
        NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y)
        )
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        dragCurrent = dragStart
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        let rect = Self.selectionRect(from: start, to: current)
        dragStart = nil
        dragCurrent = nil
        // 未拖拽或矩形过小视为取消
        if rect.width < 4 || rect.height < 4 {
            onFinish(nil)
        } else {
            onFinish(rect)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onFinish(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onFinish(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

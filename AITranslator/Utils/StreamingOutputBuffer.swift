import Foundation

/// 流式输出缓冲与自适应节流
///
/// 累积多个 delta 后批量刷新 UI，并根据文本长度动态降频；超长文本进入“仅显示进度”模式。
@MainActor
final class StreamingOutputBuffer {
    // MARK: - 回调

    /// 把累积文本交给 UI 追加（参数为本次要追加的内容）
    var onFlush: ((String) -> Void)?

    /// 长文本模式切换通知（true = 暂停 UI 刷新，仅累积）
    var onLongTextModeChange: ((Bool) -> Void)?

    // MARK: - 配置常量

    // 更新间隔配置
    private static let shortTextIntervalMs: UInt64 = 50    // 短文本：20fps
    private static let mediumTextIntervalMs: UInt64 = 160  // 中等文本：~6fps
    private static let longTextIntervalMs: UInt64 = 300    // 长文本：~3fps（降低卡顿但保持实时感）

    // 文本长度阈值
    private static let shortTextThreshold = 500       // 500字符以下为短文本
    private static let mediumTextThreshold = 3000     // 3000字符以下为中等文本
    private static let veryLongTextThreshold = 20000  // 超过此值进入“仅显示进度”模式

    // MARK: - 状态

    // 累积多个delta后批量更新UI，大幅降低CPU占用
    private var buffer: String = ""
    private var updateTask: Task<Void, Never>?

    // 自适应批量更新间隔（毫秒）：根据文本长度动态调整
    // 短文本：更新频繁（流畅）；长文本：更新稀疏甚至暂停（降低CPU）
    private var currentIntervalMs: UInt64 = 16

    // 超长文本保护模式（仅极端场景触发）
    private(set) var isLongTextMode = false

    /// 当前 UI 已显示的字符数（用于自适应阈值判定）
    var flushedLength: (() -> Int)?

    // MARK: - 缓冲

    /// 追加到缓冲
    func append(_ delta: String) {
        buffer.append(delta)
    }

    // MARK: - 批量更新优化

    /// 启动批量更新任务
    /// 定期将缓冲区的内容刷新到UI，避免每个token都触发UI更新
    /// 自适应调整更新频率：文本越长，更新越稀疏
    func start() {
        // 如果已有任务在运行，先取消
        updateTask?.cancel()

        // 初始化为短文本间隔
        currentIntervalMs = Self.shortTextIntervalMs

        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                // 在每次循环开始时检查self
                guard let strongSelf = self else { break }

                // 等待指定间隔（自适应）
                try? await Task.sleep(nanoseconds: strongSelf.currentIntervalMs * 1_000_000)

                // 检查任务是否被取消
                guard !Task.isCancelled else { break }
                guard let self else { break }

                // 根据当前文本长度自适应调整更新间隔（在刷新前检查）
                self.adjustInterval()

                // 长文本模式：停止UI更新，只累积数据
                // 这样可以完全避免Text视图的频繁重新渲染
                if !self.isLongTextMode {
                    // 正常模式：刷新缓冲区到UI
                    self.flushNow()
                }
                // 长文本模式下，数据仍在缓冲区中累积，不会丢失
            }
        }
    }

    /// 立即刷新（缓冲空时直接返回）
    func flushNow() {
        guard !buffer.isEmpty else { return }

        onFlush?(buffer)
        buffer = ""
    }

    /// 取消循环，不刷新
    func stop() {
        updateTask?.cancel()
        updateTask = nil
    }

    /// 清空缓冲与长文本模式（不刷新）
    func reset() {
        buffer = ""
        isLongTextMode = false
    }

    /// 只丢弃未刷新的缓冲内容（保留长文本模式与节流循环）
    func discardPending() {
        buffer = ""
    }

    // MARK: - 自适应节流

    /// 根据当前输出文本长度自适应调整批量更新间隔
    /// 文本越长，更新频率越低，以降低CPU占用
    private func adjustInterval() {
        let currentLength = flushedLength?() ?? 0
        let bufferLength = buffer.count
        let totalLength = currentLength + bufferLength

        let wasLongTextMode = isLongTextMode

        if totalLength < Self.shortTextThreshold {
            // 短文本：20fps，保证流畅
            currentIntervalMs = Self.shortTextIntervalMs
            isLongTextMode = false
        } else if totalLength < Self.mediumTextThreshold {
            // 中等文本：5fps，平衡性能和流畅度
            currentIntervalMs = Self.mediumTextIntervalMs
            isLongTextMode = false
        } else if totalLength < Self.veryLongTextThreshold {
            // 长文本：1fps，大幅降低CPU占用
            currentIntervalMs = Self.longTextIntervalMs
            isLongTextMode = false
        } else {
            // 超长文本：进入“仅显示进度”模式
            // 完全停止UI更新，只在完成时显示
            isLongTextMode = true
        }

        // 更新UI状态（用于显示进度提示）
        if wasLongTextMode != isLongTextMode {
            onLongTextModeChange?(isLongTextMode)
        }
    }
}

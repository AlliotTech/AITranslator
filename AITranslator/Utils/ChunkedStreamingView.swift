import SwiftUI
import Combine

/// 分块流式文本显示组件
/// 使用增量分块避免每次流式更新都全量 split 长文本，显著降低 CPU 占用。
struct ChunkedStreamingView: View {
    let text: String
    let targetLang: String

    @StateObject private var model = ParagraphChunkModel()

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(model.paragraphs.indices, id: \.self) { index in
                let paragraph = model.paragraphs[index]

                // 只有非空段落才渲染文本，空段落渲染占位符以保持换行高度
                if !paragraph.isEmpty {
                    Text(paragraph)
                        .font(Typography.body)
                        .lineSpacing(Typography.lineSpacingComfortable)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .autoTextAlignment(for: targetLang)
                        .textSelection(.enabled)
                        .padding(.bottom, Typography.lineSpacingComfortable)
                } else {
                    // 处理空行：渲染一个不可见的字符来占据高度
                    Text(" ")
                        .font(Typography.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Typography.lineSpacingComfortable)
                }
            }
        }
        .onAppear {
            model.update(with: text)
        }
        .onChange(of: text) { _, newValue in
            model.update(with: newValue)
        }
    }
}

@MainActor
private final class ParagraphChunkModel: ObservableObject {
    @Published private(set) var paragraphs: [String] = []

    private var lastText: String = ""

    func update(with newText: String) {
        // 首次赋值或清空
        guard !newText.isEmpty else {
            lastText = ""
            paragraphs = []
            return
        }

        // 增量路径：新文本是旧文本前缀扩展
        if !lastText.isEmpty, newText.hasPrefix(lastText) {
            appendIncremental(from: lastText, to: newText)
            lastText = newText
            return
        }

        // 回退路径：编辑/重置/重试等场景，做一次全量重建
        paragraphs = newText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lastText = newText
    }

    private func appendIncremental(from oldText: String, to newText: String) {
        let delta = String(newText.dropFirst(oldText.count))
        guard !delta.isEmpty else { return }

        // 确保至少有一个段落容器
        if paragraphs.isEmpty { paragraphs = [""] }

        // 将 delta 按换行切块，第一块拼接到当前最后段，后续块作为新段追加
        let parts = delta.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty else { return }

        paragraphs[paragraphs.count - 1].append(parts[0])
        if parts.count > 1 {
            paragraphs.append(contentsOf: parts.dropFirst())
        }
    }
}

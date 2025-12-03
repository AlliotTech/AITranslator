import SwiftUI

/// 分块流式文本显示组件
/// 使用 LazyVStack + 按段落拆分渲染，解决长文本 SwiftUI Text 渲染性能问题
struct ChunkedStreamingView: View {
    let text: String
    let targetLang: String
    
    // 将文本拆分为段落
    // 注意：在极长文本下，每次计算这个属性可能也有开销
    // 但相比于 Text() 渲染整个长字符串，这通常更高效
    private var paragraphs: [String] {
        // 使用 split(separator:) 并保留空子序列，以保持换行格式
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                // 只有非空段落才渲染文本，空段落渲染占位符以保持换行高度
                if !paragraph.isEmpty {
                    Text(paragraph)
                        .font(Typography.body)
                        .lineSpacing(Typography.lineSpacingComfortable)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .autoTextAlignment(for: targetLang)
                        .textSelection(.enabled) // 允许选择（注意：LazyVStack 中通常只能逐段选择）
                        .padding(.bottom, Typography.lineSpacingComfortable) // 段落间距
                } else {
                    // 处理空行：渲染一个不可见的字符来占据高度
                    Text(" ")
                        .font(Typography.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Typography.lineSpacingComfortable)
                }
            }
        }
    }
}

import SwiftUI

struct DraggableDivider: View {
    let totalWidth: CGFloat
    let minPaneWidth: CGFloat
    @Binding var splitRatio: Double
    var onCommit: (() -> Void)?
    @State private var startRatio: Double? = nil

    var body: some View {
        Divider()
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: Metrics.splitDividerHitWidth)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let rMin = Double(minPaneWidth / totalWidth)
                                let rMax = 1.0 - rMin
                                if startRatio == nil { startRatio = splitRatio }
                                let delta = Double(value.translation.width / totalWidth)
                                let proposed = (startRatio ?? splitRatio) + delta
                                splitRatio = min(max(proposed, rMin), rMax)
                            }
                            .onEnded { _ in
                                startRatio = nil
                                onCommit?()
                            }
                    )
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        splitRatio = 0.5
                        onCommit?()
                    }
            )
    }
}

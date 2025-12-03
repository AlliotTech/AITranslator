import SwiftUI

enum Metrics {
    // Spacing
    static let outerPadding: CGFloat = 12
    static let innerPadding: CGFloat = 8

    // Pane visuals
    static let paneCornerRadius: CGFloat = 10
    static let paneBorderWidth: CGFloat = 1
    static let paneFocusedBorderWidth: CGFloat = 2

    // Layout constraints
    static let minPaneWidth: CGFloat = 360
    static let minPaneHeight: CGFloat = 150  // 增加最小高度，避免内容被过度挤压

    // Split behavior
    static let splitDividerHitWidth: CGFloat = 10
}

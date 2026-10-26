import SwiftUI

/// How the item views look. The Style dock changes it.
struct ItemStyle: Equatable {
    enum Fill: Hashable {
        case gradient, solid, mono
    }

    var fill = Fill.gradient
    var cornerScale = 1.0
    var summaryLines = 2
    var showsSummaries = true
}

extension EnvironmentValues {
    @Entry var itemStyle = ItemStyle()
}

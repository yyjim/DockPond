import UIKit

/// How the swatch views look. The Style dock changes it.
struct SwatchStyle: Equatable {
    enum Fill: Int {
        case solid, soft, mono
    }

    var fill = Fill.solid
    var cornerScale = 1.0
    var summaryLines = 2
    var showsSummaries = true

    static let didChange = Notification.Name("SwatchStyleDidChange")

    static var current = SwatchStyle() {
        didSet { NotificationCenter.default.post(name: didChange, object: nil) }
    }

    func color(for swatch: Swatch) -> UIColor {
        switch fill {
        case .solid: swatch.color
        case .soft: swatch.color.withAlphaComponent(0.45)
        case .mono: .systemGray
        }
    }
}

import UIKit

struct GaugeRow: Equatable {
    let name: String
    let value: String
}

extension LayoutGauge.Snapshot {
    /// The dock title: the horizontal and vertical size classes.
    var title: String {
        "\(horizontalSizeClass.name.capitalized) · \(verticalSizeClass.name.capitalized)"
    }

    var symbol: String {
        isLandscape ? "rectangle" : "rectangle.portrait"
    }

    func rows(for sections: LayoutGauge.Sections) -> [GaugeRow] {
        var rows: [GaugeRow] = []
        if sections.contains(.window) {
            rows.append(GaugeRow(name: "Window", value: Self.points(windowSize) + (isResized ? " · resized" : " · full screen")))
            rows.append(GaugeRow(name: "Screen", value: Self.points(screenSize)))
        }
        if sections.contains(.orientation) {
            var value = isLandscape ? "Landscape" : "Portrait"
            if let side = interfaceOrientation.side {
                value += " · \(side)"
            }
            rows.append(GaugeRow(name: "Orientation", value: value))
        }
        if sections.contains(.sizeClasses) {
            rows.append(GaugeRow(name: "Size class", value: "H \(horizontalSizeClass.name) · V \(verticalSizeClass.name)"))
        }
        if sections.contains(.safeArea) {
            let insets = safeAreaInsets
            rows.append(GaugeRow(
                name: "Safe area",
                value: "T \(Int(insets.top.rounded())) · L \(Int(insets.left.rounded())) · B \(Int(insets.bottom.rounded())) · R \(Int(insets.right.rounded()))"
            ))
        }
        if sections.contains(.scale) {
            rows.append(GaugeRow(name: "Scale", value: "\(displayScale.formatted())×"))
        }
        if sections.contains(.hinge), let hinge {
            let degrees = hinge.angle.converted(to: .degrees).value
            rows.append(GaugeRow(name: "Hinge", value: "\(hinge.state.rawValue) · \(Int(degrees.rounded()))°"))
        }
        if sections.contains(.fold), let fold {
            rows.append(GaugeRow(name: "Posture", value: fold.posture == .closed ? "Closed · outer display" : fold.posture.rawValue))
            if let axis = fold.axis {
                let place = fold.position.map { "at \(axis == .vertical ? "x" : "y") \(Int($0.rounded())) pt" } ?? "outside window"
                rows.append(GaugeRow(name: "Fold", value: "\(axis.rawValue) \(place) (estimated)"))
            }
        }
        return rows
    }

    private static func points(_ size: CGSize) -> String {
        "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) pt"
    }
}

extension UIUserInterfaceSizeClass {
    var name: String {
        switch self {
        case .compact: "compact"
        case .regular: "regular"
        default: "unknown"
        }
    }
}

private extension UIInterfaceOrientation {
    var side: String? {
        switch self {
        case .portrait: "upright"
        case .portraitUpsideDown: "upside down"
        case .landscapeLeft: "left"
        case .landscapeRight: "right"
        default: nil
        }
    }
}

import FloatingDock
import SwiftUI
import UIKit

extension View {
    /// Keeps `gauge.snapshot` up to date with the window that shows this view.
    public func layoutGauge(_ gauge: LayoutGauge) -> some View {
        background(GaugeAttacher(gauge: gauge))
    }

    /// Adds a floating dock whose panel shows the layout gauge. Apply it once to
    /// the root view of a scene.
    ///
    /// `systemImage` sets the icon of the dock. If it is `nil`, the icon follows the
    /// orientation of the window.
    public func gaugeDock(
        isEnabled: Bool = true,
        sections: LayoutGauge.Sections = .all,
        systemImage: String? = nil,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(id: "gauge")
    ) -> some View {
        gaugeDock(isEnabled: isEnabled, sections: sections, systemImage: systemImage, configuration: configuration) {
            EmptyView()
        }
    }

    public func gaugeDock<Actions: View>(
        isEnabled: Bool = true,
        sections: LayoutGauge.Sections = .all,
        systemImage: String? = nil,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(id: "gauge"),
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        modifier(GaugeDockModifier<Actions, EmptyView>(
            isEnabled: isEnabled,
            sections: sections,
            systemImage: systemImage,
            configuration: configuration,
            actions: actions(),
            label: nil
        ))
    }

    /// Adds a floating dock whose panel shows the layout gauge, with a custom view
    /// as its button. `systemImage` shows in the panel header.
    public func gaugeDock<Actions: View, Label: View>(
        isEnabled: Bool = true,
        sections: LayoutGauge.Sections = .all,
        systemImage: String? = nil,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(id: "gauge"),
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder label: @escaping @MainActor (FloatingDockButtonState) -> Label
    ) -> some View {
        modifier(GaugeDockModifier(
            isEnabled: isEnabled,
            sections: sections,
            systemImage: systemImage,
            configuration: configuration,
            actions: actions(),
            label: label
        ))
    }

    public func gaugeDock<Label: View>(
        isEnabled: Bool = true,
        sections: LayoutGauge.Sections = .all,
        systemImage: String? = nil,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(id: "gauge"),
        @ViewBuilder label: @escaping @MainActor (FloatingDockButtonState) -> Label
    ) -> some View {
        gaugeDock(
            isEnabled: isEnabled,
            sections: sections,
            systemImage: systemImage,
            configuration: configuration,
            actions: { EmptyView() },
            label: label
        )
    }
}

/// The gauge rows, for use inside a floating dock or any other view.
public struct LayoutGaugeView: View {
    private let gauge: LayoutGauge
    private let sections: LayoutGauge.Sections

    public init(_ gauge: LayoutGauge, sections: LayoutGauge.Sections = .all) {
        self.gauge = gauge
        self.sections = sections
    }

    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
            ForEach(gauge.snapshot.rows(for: sections), id: \.name) { row in
                GridRow {
                    Text(row.name)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                    Text(row.value)
                }
            }
        }
        .font(.caption2.monospaced())
    }
}

private struct GaugeDockModifier<Actions: View, Label: View>: ViewModifier {
    let isEnabled: Bool
    let sections: LayoutGauge.Sections
    let systemImage: String?
    let configuration: FloatingDockConfiguration
    let actions: Actions
    let label: (@MainActor (FloatingDockButtonState) -> Label)?
    @State private var gauge = LayoutGauge()

    @ViewBuilder
    func body(content: Content) -> some View {
        let measured = content.layoutGauge(gauge)
        let image = systemImage ?? gauge.snapshot.symbol
        if let label {
            measured.floatingDock(
                isEnabled: isEnabled,
                title: gauge.snapshot.title,
                systemImage: image,
                configuration: configuration,
                content: { LayoutGaugeView(gauge, sections: sections) },
                actions: { actions },
                label: label
            )
        } else {
            measured.floatingDock(
                isEnabled: isEnabled,
                title: gauge.snapshot.title,
                systemImage: image,
                configuration: configuration,
                content: { LayoutGaugeView(gauge, sections: sections) },
                actions: { actions }
            )
        }
    }
}

private struct GaugeAttacher: UIViewRepresentable {
    let gauge: LayoutGauge

    func makeUIView(context: Context) -> WindowProbeView {
        let view = WindowProbeView()
        view.isUserInteractionEnabled = false
        view.onWindowChange = { [gauge] window in
            if let window {
                gauge.attach(to: window)
            }
        }
        return view
    }

    func updateUIView(_ view: WindowProbeView, context: Context) {}
}

private final class WindowProbeView: UIView {
    var onWindowChange: ((UIWindow?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?(window)
    }
}

extension DockTool {
    /// A dock tool with the gauge rows. Attach the gauge to the app window first,
    /// with `.layoutGauge(_:)` in SwiftUI or `attach(to:)` in UIKit.
    @MainActor
    public static func layoutGauge(_ gauge: LayoutGauge, sections: LayoutGauge.Sections = .all) -> DockTool {
        DockTool("Layout", systemImage: "ruler", id: "layout-gauge") {
            LayoutGaugeView(gauge, sections: sections)
        }
    }
}

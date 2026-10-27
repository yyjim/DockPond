import FloatingDock
import GaugeDock
import SwiftUI

@main
struct SwiftUIDemoApp: App {
    @State private var settings = DemoSettings()
    @State private var diagnostics = DuoDiagnostics()

    var body: some Scene {
        WindowGroup {
            RootView(settings: settings, diagnostics: diagnostics)
                .environment(\.itemStyle, settings.itemStyle)
                .floatingDock(
                    title: "Dev Tools",
                    systemImage: "wrench.and.screwdriver",
                    panelStyle: .tabs,
                    configuration: FloatingDockConfiguration(id: "dev-tools")
                ) {
                    if diagnostics.hasHinge {
                        DockTool.selector("Hinge", selection: $settings.stateOverride, options: [
                            "Live": nil, "Closed": .closed, "Half": .partiallyOpen, "Flat": .fullyOpen,
                        ])
                        DockTool.selector("Fold axis", selection: $settings.axisOverride, options: [
                            "Auto": nil, "Vertical": .vertical, "Horizontal": .horizontal,
                        ])
                        DockTool.toggle("Fold line", isOn: $settings.showsFoldLine)
                    }
                    DockTool("Controls", systemImage: "slider.horizontal.3") {
                        TestControlsPanel(settings: settings)
                    } actions: {
                        if diagnostics.hasHinge {
                            Button("History", systemImage: "clock.arrow.circlepath") {
                                settings.isShowingHistory = true
                            }
                        }
                    }
                    DockTool.appearance()
                }
                .floatingDock(
                    title: "Style",
                    systemImage: "paintpalette",
                    panelStyle: .sections,
                    configuration: FloatingDockConfiguration(id: "style", initialPosition: 0.35)
                ) {
                    DockTool.selector("Fill", selection: $settings.itemStyle.fill, options: [
                        "Gradient": .gradient, "Solid": .solid, "Mono": .mono,
                    ])
                    DockTool.slider("Corners", value: $settings.itemStyle.cornerScale, in: 0...2)
                    DockTool.toggle("Summaries", isOn: $settings.itemStyle.showsSummaries)
                    DockTool.stepper("Lines", value: $settings.itemStyle.summaryLines, in: 1...4)
                    DockTool.button("Reset", systemImage: "arrow.counterclockwise") {
                        settings.itemStyle = ItemStyle()
                    }
                }
                .gaugeDock(configuration: FloatingDockConfiguration(id: "gauge", initialEdge: .leading))
        }
    }
}

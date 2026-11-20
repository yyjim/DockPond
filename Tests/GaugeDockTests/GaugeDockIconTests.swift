import FloatingDock
@testable import GaugeDock
import Testing

@MainActor
struct GaugeDockIconTests {
    @Test func followsTheGaugeByDefault() {
        let gauge = LayoutGauge()
        let dock = FloatingDockController.gaugeDock(gauge)
        #expect(dock.systemImage == gauge.snapshot.symbol)
    }

    @Test func keepsACustomIcon() {
        let dock = FloatingDockController.gaugeDock(LayoutGauge(), systemImage: "ruler")
        #expect(dock.systemImage == "ruler")
    }
}

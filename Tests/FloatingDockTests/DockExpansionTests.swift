@testable import FloatingDock
import Testing
import UIKit

@MainActor
struct DockExpansionTests {
    @Test func aCollapseDuringAnExpandRunsToItsEnd() async throws {
        let alone = try await secondsUntilPanelHides(expandLead: nil)
        let duringExpand = try await secondsUntilPanelHides(expandLead: .milliseconds(300))

        #expect(duringExpand > alone - 0.1)
    }

    private func secondsUntilPanelHides(expandLead: Duration?) async throws -> Double {
        let controller = DockViewController(model: DockModel(), configuration: FloatingDockConfiguration(id: UUID().uuidString))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        let panel = try #require(controller.view.subviews.first)

        controller.setExpanded(true, animated: expandLead != nil)
        try await Task.sleep(for: expandLead ?? .milliseconds(100))

        let start = CACurrentMediaTime()
        controller.setExpanded(false)
        while !panel.isHidden, CACurrentMediaTime() - start < 3 {
            try await Task.sleep(for: .milliseconds(5))
        }
        return CACurrentMediaTime() - start
    }
}

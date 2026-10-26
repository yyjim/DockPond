import CoreGraphics
import Foundation
import Testing
@testable import FloatingDock

struct DockPositionTests {
    let area = CGRect(x: 0, y: 0, width: 400, height: 800)
    let item = CGSize(width: 60, height: 60)

    @Test func docksToTheNearerSide() {
        #expect(DockPosition.nearest(to: CGPoint(x: 100, y: 400), in: area, itemSize: item).edge == .leading)
        #expect(DockPosition.nearest(to: CGPoint(x: 300, y: 400), in: area, itemSize: item).edge == .trailing)
    }

    @Test func docksToTopOrBottomOnlyNearThem() {
        #expect(DockPosition.nearest(to: CGPoint(x: 200, y: 40), in: area, itemSize: item).edge == .top)
        #expect(DockPosition.nearest(to: CGPoint(x: 200, y: 770), in: area, itemSize: item).edge == .bottom)
        #expect(DockPosition.nearest(to: CGPoint(x: 200, y: 200), in: area, itemSize: item).edge != .top)
    }

    @Test func clampsTheFractionToTheEdge() {
        let position = DockPosition.nearest(to: CGPoint(x: 10, y: -500), in: area, itemSize: item)
        #expect(position.fraction == 0)
    }

    @Test func keepsTheSpotAlongTheEdgeWhenTheAreaChanges() {
        let position = DockPosition(edge: .trailing, fraction: 0.5)
        let portrait = position.center(in: area, itemSize: item)
        let landscape = position.center(in: CGRect(x: 0, y: 0, width: 800, height: 400), itemSize: item)
        #expect(portrait == CGPoint(x: 370, y: 400))
        #expect(landscape == CGPoint(x: 770, y: 200))
    }

    @Test func savesAndLoadsPerDockID() throws {
        let defaults = try #require(UserDefaults(suiteName: "DockPositionTests"))
        defaults.removePersistentDomain(forName: "DockPositionTests")
        let fallback = DockPosition(edge: .trailing, fraction: 0.7)

        #expect(DockPosition.load(id: "a", default: fallback, defaults: defaults) == fallback)

        DockPosition(edge: .top, fraction: 0.25).save(id: "a", defaults: defaults)
        #expect(DockPosition.load(id: "a", default: fallback, defaults: defaults) == DockPosition(edge: .top, fraction: 0.25))
        #expect(DockPosition.load(id: "b", default: fallback, defaults: defaults) == fallback)
    }
}

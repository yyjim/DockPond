import CoreGraphics
import Testing
@testable import FloatingDock

struct PanelPlacementTests {
    let area = CGRect(x: 10, y: 20, width: 800, height: 600)
    let size = CGSize(width: 340, height: 200)

    @Test func returnsTheOriginItWasMadeFrom() {
        let placement = PanelPlacement(origin: CGPoint(x: 100, y: 150), size: size, in: area)
        #expect(placement.origin(for: size, in: area) == CGPoint(x: 100, y: 150))
    }

    @Test func keepsThePanelInsideTheArea() {
        let placement = PanelPlacement(origin: CGPoint(x: 2000, y: -500), size: size, in: area)
        #expect(placement.origin(for: size, in: area) == CGPoint(x: 470, y: 20))
    }

    @Test func keepsTheTopEdgeWhenTheHeightChanges() {
        let placement = PanelPlacement(origin: CGPoint(x: 100, y: 150), size: size, in: area)
        let taller = CGSize(width: 340, height: 300)
        #expect(placement.origin(for: taller, in: area) == CGPoint(x: 100, y: 150))
    }

    @Test func movesUpWhenTheNewHeightDoesNotFitBelowTheTopEdge() {
        let placement = PanelPlacement(origin: CGPoint(x: 100, y: 400), size: size, in: area)
        let taller = CGSize(width: 340, height: 500)
        #expect(placement.origin(for: taller, in: area).y == 120)
    }

    @Test func snapsToTheEdgeWithTheSmallestGap() {
        let nearLeading = PanelPlacement.snapped(origin: CGPoint(x: 60, y: 200), size: size, in: area)
        #expect(nearLeading.edge == .leading)
        #expect(nearLeading.origin(for: size, in: area) == CGPoint(x: 10, y: 200))

        let nearBottom = PanelPlacement.snapped(origin: CGPoint(x: 200, y: 400), size: size, in: area)
        #expect(nearBottom.edge == .bottom)
        #expect(nearBottom.origin(for: size, in: area) == CGPoint(x: 200, y: 420))
    }

    @Test func aPanelAsWideAsTheAreaKeepsItsVerticalPosition() {
        let phone = CGRect(x: 8, y: 60, width: 340, height: 700)
        let placement = PanelPlacement.snapped(origin: CGPoint(x: 8, y: 300), size: size, in: phone)
        #expect(placement.edge == .leading)
        #expect(placement.origin(for: size, in: phone) == CGPoint(x: 8, y: 300))
    }

    @Test func aPanelAsTallAsTheAreaDocksToASideEdge() {
        let tall = CGSize(width: 340, height: 600)
        let placement = PanelPlacement.snapped(origin: CGPoint(x: 440, y: 20), size: tall, in: area)
        #expect(placement.edge == .trailing)
        #expect(placement.origin(for: tall, in: area) == CGPoint(x: 470, y: 20))

        let almostAsTall = CGSize(width: 340, height: 590)
        #expect(PanelPlacement.snapped(origin: CGPoint(x: 440, y: 22), size: almostAsTall, in: area).edge == .trailing)
    }

    @Test func equalGapsGoToThePreferredEdge() {
        let phone = CGRect(x: 8, y: 60, width: 340, height: 700)
        let origin = CGPoint(x: 8, y: 300)
        #expect(PanelPlacement.snapped(origin: origin, size: size, in: phone, preferring: .trailing).edge == .trailing)
        #expect(PanelPlacement.snapped(origin: origin, size: size, in: phone, preferring: .top).edge == .leading)

        let fractional = CGRect(x: 8.3, y: 60, width: 340.4, height: 700)
        #expect(PanelPlacement.snapped(origin: origin, size: size, in: fractional, preferring: .trailing).edge == .trailing)
    }

    @Test func aSnappedPanelStaysOnItsEdgeWhenTheAreaChanges() {
        let placement = PanelPlacement.snapped(origin: CGPoint(x: 460, y: 100), size: size, in: area)
        let wider = CGRect(x: 0, y: 0, width: 1200, height: 600)
        #expect(placement.origin(for: size, in: wider).x == 860)
    }

    @Test func aSnappedBottomPanelGrowsUpward() {
        let placement = PanelPlacement.snapped(origin: CGPoint(x: 200, y: 400), size: size, in: area)
        let taller = CGSize(width: 340, height: 300)
        #expect(placement.origin(for: taller, in: area).y == 320)
    }

    @Test func keepsTheSideWhenTheAreaChanges() {
        let placement = PanelPlacement(origin: CGPoint(x: 470, y: 20), size: size, in: area)
        let portrait = CGRect(x: 0, y: 0, width: 400, height: 800)
        #expect(placement.origin(for: size, in: portrait) == CGPoint(x: 60, y: 0))
    }
}

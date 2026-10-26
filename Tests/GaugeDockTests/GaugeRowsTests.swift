import Foundation
import Testing
import UIKit
@testable import GaugeDock

struct GaugeRowsTests {
    let snapshot = LayoutGauge.Snapshot(
        windowSize: CGSize(width: 951, height: 669),
        screenSize: CGSize(width: 951, height: 669),
        isResized: false,
        interfaceOrientation: .landscapeRight,
        horizontalSizeClass: .regular,
        verticalSizeClass: .compact,
        safeAreaInsets: UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
        displayScale: 3,
        hinge: nil,
        fold: nil
    )

    @Test func titleShowsTheSizeClasses() {
        #expect(snapshot.title == "Regular · Compact")
        #expect(snapshot.symbol == "rectangle")
    }

    @Test func rowsDescribeTheLayout() {
        #expect(snapshot.rows(for: .all) == [
            GaugeRow(name: "Window", value: "951 × 669 pt · full screen"),
            GaugeRow(name: "Screen", value: "951 × 669 pt"),
            GaugeRow(name: "Orientation", value: "Landscape · right"),
            GaugeRow(name: "Size class", value: "H regular · V compact"),
            GaugeRow(name: "Safe area", value: "T 0 · L 59 · B 21 · R 59"),
            GaugeRow(name: "Scale", value: "3×"),
        ])
    }

    @Test func hingeRowAppearsOnlyWithAHinge() {
        var withHinge = snapshot
        withHinge.hinge = LayoutGauge.Hinge(state: .partiallyOpen, angle: Measurement(value: 92, unit: .degrees))
        #expect(withHinge.rows(for: .hinge) == [GaugeRow(name: "Hinge", value: "Half Open · 92°")])
        #expect(snapshot.rows(for: .hinge).isEmpty)
    }

    @Test func foldRowsAppearOnlyWithAHinge() {
        #expect(snapshot.rows(for: .fold).isEmpty)

        var closed = snapshot
        closed.fold = LayoutGauge.Fold(posture: .closed, axis: nil, position: nil)
        #expect(closed.rows(for: .fold) == [GaugeRow(name: "Posture", value: "Closed · outer display")])

        var book = snapshot
        book.fold = LayoutGauge.Fold(posture: .book, axis: .vertical, position: 475.5)
        #expect(book.rows(for: .fold) == [
            GaugeRow(name: "Posture", value: "Book"),
            GaugeRow(name: "Fold", value: "Vertical at x 476 pt (estimated)"),
        ])

        var outside = snapshot
        outside.fold = LayoutGauge.Fold(posture: .tabletop, axis: .horizontal, position: nil)
        #expect(outside.rows(for: .fold).last == GaugeRow(name: "Fold", value: "Horizontal outside window (estimated)"))
    }

    @Test func resizedWindowIsMarked() {
        var resized = snapshot
        resized.windowSize = CGSize(width: 475, height: 669)
        resized.isResized = true
        #expect(resized.rows(for: .window).first == GaugeRow(name: "Window", value: "475 × 669 pt · resized"))
        #expect(resized.symbol == "rectangle.portrait")
    }
}

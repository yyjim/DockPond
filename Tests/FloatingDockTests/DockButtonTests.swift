import SwiftUI
import Testing
import UIKit
@testable import FloatingDock

@MainActor
struct DockButtonTests {
    @Test func keepsAHitAreaOfAtLeast44Points() {
        let button = DockButton(id: "small")
        button.bounds.size = CGSize(width: 30, height: 30)
        #expect(button.point(inside: CGPoint(x: -6, y: 15), with: nil))
        #expect(button.point(inside: CGPoint(x: 36, y: 36), with: nil))
        #expect(!button.point(inside: CGPoint(x: -8, y: 15), with: nil))
    }

    @Test func doesNotGrowALargeHitArea() {
        let button = DockButton(id: "large")
        button.bounds.size = CGSize(width: 60, height: 60)
        #expect(button.point(inside: CGPoint(x: 1, y: 1), with: nil))
        #expect(!button.point(inside: CGPoint(x: -1, y: 30), with: nil))
    }

    @Test func showsTheCustomLabelInPlaceOfTheDefaultLook() {
        let button = DockButton(id: "label")
        let label = UIView()
        button.setLabelView(label)
        #expect(label.isHidden)
        #expect(!label.isUserInteractionEnabled)
        #expect(label.accessibilityElementsHidden)

        button.showsCustomLabel = true
        #expect(!label.isHidden)
        #expect(button.layer.shadowOpacity == 0)

        button.showsCustomLabel = false
        #expect(label.isHidden)
        #expect(button.layer.shadowOpacity == 0.25)
    }

    @Test func passesTheStateToTheLabel() {
        var received: [FloatingDockButtonState] = []
        let label = DockButtonLabel { state in
            received.append(state)
            return Text("Duck")
        }
        let state = FloatingDockButtonState(edge: .leading, isDragging: true, isExpanded: false, isIdle: false)
        _ = label.body(state)
        #expect(received == [state])
    }

    @Test func stateDefaultsToARestingButtonOnTheTrailingEdge() {
        #expect(FloatingDockButtonState() == FloatingDockButtonState(edge: .trailing, isDragging: false, isExpanded: false, isIdle: false))
    }
}

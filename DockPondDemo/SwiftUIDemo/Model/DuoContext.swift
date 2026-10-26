import SwiftUI

extension HingeState {
    @available(iOS 27.1, *)
    init(_ hinge: DeviceHinge?) {
        guard let status = hinge?.status else {
            self = .unavailable
            return
        }
        switch status {
        case .closed: self = .closed
        case .partiallyOpen: self = .partiallyOpen
        case .fullyOpen: self = .fullyOpen
        default: self = .unavailable
        }
    }
}

struct HingeReading: Equatable {
    var state: HingeState
    var angle: Angle?

    static let unavailable = HingeReading(state: .unavailable, angle: nil)

    init(state: HingeState, angle: Angle?) {
        self.state = state
        self.angle = angle
    }

    @available(iOS 27.1, *)
    init(_ context: DeviceHingeContext) {
        self.init(state: HingeState(context.hinge), angle: context.hinge?.angle)
    }
}

/// Everything a layout needs to decide how to present itself on iPhone Duo.
///
/// The fold position comes from the window geometry, because the SDK reports the
/// hinge state and angle but not where the fold sits. On the Duo inner display each
/// half matches the outer display, so the fold always bisects the longer edge.
struct DuoContext: Equatable {
    var hasHinge: Bool
    var reading: HingeReading
    var windowSize: CGSize
    var safeAreaInsets: EdgeInsets
    var horizontalSizeClass: UserInterfaceSizeClass?
    var axisOverride: FoldAxis?

    static let foldGutter: CGFloat = 28

    var isLandscape: Bool { windowSize.width > windowSize.height }

    var foldAxis: FoldAxis { axisOverride ?? (isLandscape ? .vertical : .horizontal) }

    var posture: Posture {
        Posture(state: reading.state, foldAxis: foldAxis, isRegularWidth: horizontalSizeClass == .regular)
    }

    var hasFold: Bool { reading.state == .partiallyOpen || reading.state == .fullyOpen }

    /// The fold center in the coordinate space of the safe-area content.
    var foldCenterInContent: CGPoint {
        CGPoint(
            x: windowSize.width / 2 - safeAreaInsets.leading,
            y: windowSize.height / 2 - safeAreaInsets.top
        )
    }

    static let placeholder = DuoContext(
        hasHinge: false,
        reading: .unavailable,
        windowSize: .zero,
        safeAreaInsets: EdgeInsets(),
        horizontalSizeClass: nil,
        axisOverride: nil
    )
}

extension EnvironmentValues {
    @Entry var duoContext = DuoContext.placeholder
}

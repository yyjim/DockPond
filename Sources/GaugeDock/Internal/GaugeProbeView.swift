import UIKit

/// An invisible full-window view that measures its window whenever the layout,
/// the traits, the safe area, or the hinge change.
final class GaugeProbeView: UIView {
    private let onMeasure: (LayoutGauge.Snapshot) -> Void
    private var hinge: LayoutGauge.Hinge?

    init(onMeasure: @escaping (LayoutGauge.Snapshot) -> Void) {
        self.onMeasure = onMeasure
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        registerForTraitChanges(
            [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self, UITraitDisplayScale.self]
        ) { (self: Self, _) in
            self.measure()
        }
        if #available(iOS 27.1, *) {
            observeHinge()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        measure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        measure()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        measure()
    }

    private func measure() {
        guard let window else { return }
        let scene = window.windowScene
        let windowSize = window.bounds.size
        let screenSize = scene?.screen.bounds.size ?? windowSize
        onMeasure(LayoutGauge.Snapshot(
            windowSize: windowSize,
            screenSize: screenSize,
            isResized: windowSize.width < screenSize.width - 0.5 || windowSize.height < screenSize.height - 0.5,
            interfaceOrientation: scene?.effectiveGeometry.interfaceOrientation ?? .unknown,
            horizontalSizeClass: traitCollection.horizontalSizeClass,
            verticalSizeClass: traitCollection.verticalSizeClass,
            safeAreaInsets: window.safeAreaInsets,
            displayScale: traitCollection.displayScale,
            hinge: hinge,
            fold: hinge.map { estimateFold(for: $0, in: window) }
        ))
    }

    private func estimateFold(for hinge: LayoutGauge.Hinge, in window: UIWindow) -> LayoutGauge.Fold {
        guard hinge.state != .closed, let screen = window.windowScene?.screen else {
            return LayoutGauge.Fold(posture: .closed, axis: nil, position: nil)
        }
        let screenBounds = screen.bounds
        let axis: LayoutGauge.Fold.Axis = screenBounds.width > screenBounds.height ? .vertical : .horizontal
        let center = window.convert(CGPoint(x: screenBounds.midX, y: screenBounds.midY), from: screen.coordinateSpace)
        let position: CGFloat? = switch axis {
        case .vertical: (0...window.bounds.width).contains(center.x) ? center.x : nil
        case .horizontal: (0...window.bounds.height).contains(center.y) ? center.y : nil
        }
        let posture: LayoutGauge.Fold.Posture = switch hinge.state {
        case .fullyOpen: .flat
        default: axis == .vertical ? .book : .tabletop
        }
        return LayoutGauge.Fold(posture: posture, axis: axis, position: position)
    }

    @available(iOS 27.1, *)
    private func observeHinge() {
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            hinge = update.hinge.flatMap { hinge in
                let state: LayoutGauge.Hinge.State? = switch hinge.status {
                case .closed: .closed
                case .partiallyOpen: .partiallyOpen
                case .fullyOpen: .fullyOpen
                default: nil
                }
                return state.map {
                    LayoutGauge.Hinge(state: $0, angle: Measurement(value: Double(hinge.angle), unit: .radians))
                }
            }
            measure()
        }
        addInteraction(interaction)
    }
}

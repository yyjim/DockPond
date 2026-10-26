import UIKit

/// Reads the hinge and the window shape, and shows the screen for the current
/// posture: the split view, the book spread, or the tabletop viewer.
final class DuoRootViewController: UIViewController {
    let settings = DuoSettings()
    var onStateChange: ((DuoState) -> Void)?
    var onSelectionChange: ((Swatch) -> Void)?

    private let foldLine = FoldLineView()
    private var liveReading = HingeReading.unavailable
    private var lastState: DuoState?
    private var child: UIViewController?

    private(set) var selection = Swatch.all[7] {
        didSet {
            split.show(selection)
            book.swatch = selection
            tabletop.swatch = selection
            onSelectionChange?(selection)
        }
    }

    private lazy var split = SplitViewController(selection: selection) { [weak self] in self?.selection = $0 }
    private lazy var book = BookViewController(swatch: selection) { [weak self] in self?.selection = $0 }
    private lazy var tabletop = TabletopViewController(swatch: selection) { [weak self] in self?.selection = $0 }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(foldLine)
        settings.onChange = { [weak self] in self?.refresh() }
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _) in
            self.refresh()
        }
        if #available(iOS 27.1, *) {
            observeHinge()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refresh()
    }

    func showAbout() {
        let alert = UIAlertController(
            title: "UIKit Demo",
            message: "This app installs two docks from its SceneDelegate. Dev Tools shows its tools as sections: the layout gauge from GaugeDock, the hinge element tools, a custom UIKit Controls view, and the ready-made Appearance tool. Style has only element tools, so it shows them without tabs or headers.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showHistory() {
        let navigation = UINavigationController(rootViewController: HingeHistoryViewController(settings: settings))
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        present(navigation, animated: true)
    }

    func selectPrevious() {
        selection = selection.previous
    }

    func selectNext() {
        selection = selection.next
    }

    private func refresh() {
        let hasHinge = liveReading.state != .unavailable
        let stateOverride = hasHinge ? settings.stateOverride : nil
        let state = DuoState(
            hasHinge: hasHinge,
            reading: stateOverride.map { HingeReading(state: $0, angleDegrees: nil) } ?? liveReading,
            windowSize: view.bounds.size,
            horizontalSizeClass: traitCollection.horizontalSizeClass,
            axisOverride: hasHinge ? settings.axisOverride : nil
        )

        show(controller(for: state.posture))
        child?.view.frame = view.bounds
        foldLine.frame = view.bounds
        foldLine.axis = state.foldAxis
        foldLine.isHidden = !(settings.showsFoldLine && state.hasFold)
        view.bringSubviewToFront(foldLine)

        guard state != lastState else { return }
        lastState = state
        onStateChange?(state)
    }

    private func controller(for posture: Posture) -> UIViewController {
        switch posture {
        case .outer, .flat, .compact, .regular: split
        case .book: book
        case .tabletop: tabletop
        }
    }

    private func show(_ controller: UIViewController) {
        guard controller !== child else { return }
        if let child {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        addChild(controller)
        view.insertSubview(controller.view, belowSubview: foldLine)
        controller.didMove(toParent: self)
        child = controller
    }

    @available(iOS 27.1, *)
    private func observeHinge() {
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            let reading: HingeReading
            if let hinge = update.hinge {
                let state: HingeState = switch hinge.status {
                case .closed: .closed
                case .partiallyOpen: .partiallyOpen
                case .fullyOpen: .fullyOpen
                default: .unavailable
                }
                reading = HingeReading(state: state, angleDegrees: Int((hinge.angle * 180 / .pi).rounded()))
            } else {
                reading = .unavailable
            }
            liveReading = reading
            settings.record(reading)
            refresh()
        }
        view.addInteraction(interaction)
    }
}

/// A debug line where the app assumes the fold is: the middle of the window,
/// across its longer edge unless Fold Axis is forced.
final class FoldLineView: UIView {
    var axis = FoldAxis.vertical {
        didSet { setNeedsLayout() }
    }

    private let line = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        line.strokeColor = UIColor.systemRed.withAlphaComponent(0.7).cgColor
        line.lineWidth = 2
        line.lineDashPattern = [8, 6]
        layer.addSublayer(line)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        switch axis {
        case .vertical:
            path.move(to: CGPoint(x: bounds.midX, y: 0))
            path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
        case .horizontal:
            path.move(to: CGPoint(x: 0, y: bounds.midY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        }
        line.frame = bounds
        line.path = path.cgPath
    }
}

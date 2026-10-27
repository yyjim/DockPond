import SwiftUI
import UIKit

@MainActor
final class DockViewController: UIViewController {
    private let model: DockModel
    private let configuration: FloatingDockConfiguration
    private let button: DockButton
    private lazy var panelHost = UIHostingController(
        rootView: DockPanel(model: model, id: configuration.id) { [weak self] in self?.setExpanded(false) }
    )
    private var position: DockPosition
    private(set) var isExpanded = false
    private var isDragging = false
    private var dragStartCenter = CGPoint.zero
    private var idleTask: Task<Void, Never>?

    private let margin: CGFloat = 8
    private let panelMaxWidth: CGFloat = 340
    private var buttonSize: CGSize { CGSize(width: configuration.buttonSize, height: configuration.buttonSize) }

    init(model: DockModel, configuration: FloatingDockConfiguration) {
        self.model = model
        self.configuration = configuration
        self.button = DockButton(id: configuration.id)
        self.position = DockPosition.load(
            id: configuration.id,
            default: DockPosition(edge: configuration.initialEdge, fraction: configuration.initialPosition)
        )
        super.init(nibName: nil, bundle: nil)
        OpenDocks.register(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        addChild(panelHost)
        panelHost.view.backgroundColor = .clear
        panelHost.safeAreaRegions = []
        panelHost.sizingOptions = .preferredContentSize
        panelHost.view.isHidden = true
        view.addSubview(panelHost.view)
        panelHost.didMove(toParent: self)

        button.bounds.size = buttonSize
        button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        button.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
        view.addSubview(button)
        scheduleIdleFade()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !isDragging {
            button.center = position.center(in: dockingArea, itemSize: buttonSize)
        }
        if isExpanded {
            layoutPanel()
        }
    }

    /// The panel content changed size, for example after a tab switch, a section
    /// collapse, or new rows.
    override func preferredContentSizeDidChange(forChildContentContainer container: any UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        guard isExpanded else { return }
        UIView.animate(springDuration: 0.3, bounce: 0, options: .allowUserInteraction) {
            self.layoutPanel()
        }
    }

    func updateButton(title: String, systemImage: String) {
        button.setSymbol(systemImage)
        button.accessibilityLabel = title
    }

    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard isViewLoaded, expanded != isExpanded else { return }
        isExpanded = expanded
        idleTask?.cancel()
        let panel = panelHost.view!

        if expanded {
            OpenDocks.closeOthers(than: self)
            model.presentationCount += 1
            panel.transform = .identity
            layoutPanel()
            panel.isHidden = false
            panel.alpha = 0
            panel.transform = transformTowardButton(for: panel)
        }

        let changes = {
            panel.alpha = expanded ? 1 : 0
            panel.transform = expanded ? .identity : self.transformTowardButton(for: panel)
            self.button.alpha = expanded ? 0 : 1
            self.button.transform = expanded ? CGAffineTransform(scaleX: 0.6, y: 0.6) : .identity
        }
        let completion = { (_: Bool) in
            guard !self.isExpanded else { return }
            panel.isHidden = true
            panel.transform = .identity
            self.scheduleIdleFade()
        }
        if animated {
            UIView.animate(springDuration: 0.4, bounce: expanded ? 0.2 : 0, options: .allowUserInteraction, animations: changes, completion: completion)
        } else {
            changes()
            completion(true)
        }
    }

    private var dockingArea: CGRect {
        view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: margin, dy: margin)
    }

    private func layoutPanel() {
        let area = dockingArea
        let width = min(panelMaxWidth, area.width)
        let fitting = panelHost.sizeThatFits(in: CGSize(width: width, height: area.height))
        let size = CGSize(width: width, height: min(fitting.height, area.height))

        var origin: CGPoint
        switch position.edge {
        case .leading:
            origin = CGPoint(x: area.minX, y: button.center.y - size.height / 2)
        case .trailing:
            origin = CGPoint(x: area.maxX - size.width, y: button.center.y - size.height / 2)
        case .top:
            origin = CGPoint(x: button.center.x - size.width / 2, y: area.minY)
        case .bottom:
            origin = CGPoint(x: button.center.x - size.width / 2, y: area.maxY - size.height)
        }
        origin.x = min(max(origin.x, area.minX), area.maxX - size.width)
        origin.y = min(max(origin.y, area.minY), area.maxY - size.height)

        panelHost.view.bounds.size = size
        panelHost.view.center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }

    private func transformTowardButton(for panel: UIView) -> CGAffineTransform {
        CGAffineTransform(translationX: button.center.x - panel.center.x, y: button.center.y - panel.center.y)
            .scaledBy(x: 0.15, y: 0.15)
    }

    @objc private func handleTap() {
        setExpanded(true)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDragging = true
            dragStartCenter = button.center
            wake()
        case .changed:
            let translation = gesture.translation(in: view)
            button.center = clamped(CGPoint(x: dragStartCenter.x + translation.x, y: dragStartCenter.y + translation.y))
        case .ended, .cancelled, .failed:
            let velocity = gesture.velocity(in: view)
            let projected = CGPoint(x: button.center.x + velocity.x * 0.12, y: button.center.y + velocity.y * 0.12)
            position = DockPosition.nearest(to: clamped(projected), in: dockingArea, itemSize: buttonSize)
            position.save(id: configuration.id)
            isDragging = false
            UIView.animate(springDuration: 0.45, bounce: 0.25, options: .allowUserInteraction) {
                self.button.center = self.position.center(in: self.dockingArea, itemSize: self.buttonSize)
            }
            scheduleIdleFade()
        default:
            break
        }
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        let area = view.bounds.inset(by: view.safeAreaInsets)
        return CGPoint(
            x: min(max(point.x, area.minX + buttonSize.width / 2), area.maxX - buttonSize.width / 2),
            y: min(max(point.y, area.minY + buttonSize.height / 2), area.maxY - buttonSize.height / 2)
        )
    }

    // UIKit blocks touches on a view while it animates unless the animation
    // passes .allowUserInteraction, so a tap during a fade would be lost.
    private func wake() {
        idleTask?.cancel()
        UIView.animate(withDuration: 0.15, delay: 0, options: .allowUserInteraction) { self.button.alpha = 1 }
    }

    private func scheduleIdleFade() {
        idleTask?.cancel()
        let delay = configuration.idleDelay
        let opacity = configuration.idleOpacity
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, !self.isExpanded, !self.isDragging else { return }
            UIView.animate(withDuration: 0.4, delay: 0, options: .allowUserInteraction) { self.button.alpha = opacity }
        }
    }
}

/// Keeps one panel open at a time in each window scene. A tap on another dock's
/// button does not always reach this dock's outside-tap check, because the window
/// on top takes the touch first.
@MainActor
private enum OpenDocks {
    private struct WeakDock {
        weak var value: DockViewController?
    }

    private static var docks: [WeakDock] = []

    static func register(_ dock: DockViewController) {
        docks.removeAll { $0.value == nil }
        docks.append(WeakDock(value: dock))
    }

    static func closeOthers(than dock: DockViewController) {
        let scene = dock.view.window?.windowScene
        for other in docks.compactMap(\.value) where other !== dock && other.view.window?.windowScene === scene {
            other.setExpanded(false)
        }
    }
}

/// A dock position that survives rotation and folding: an edge, plus a fraction
/// along that edge.
struct DockPosition: Equatable {
    typealias Edge = FloatingDockConfiguration.Edge

    var edge: Edge
    var fraction: CGFloat

    static func load(id: String, default defaultPosition: DockPosition, defaults: UserDefaults = .standard) -> DockPosition {
        guard let edge = defaults.string(forKey: edgeKey(id)).flatMap(Edge.init(rawValue:)) else {
            return defaultPosition
        }
        let fraction = defaults.object(forKey: fractionKey(id)) as? Double ?? defaultPosition.fraction
        return DockPosition(edge: edge, fraction: fraction)
    }

    func save(id: String, defaults: UserDefaults = .standard) {
        defaults.set(edge.rawValue, forKey: Self.edgeKey(id))
        defaults.set(Double(fraction), forKey: Self.fractionKey(id))
    }

    private static func edgeKey(_ id: String) -> String { "FloatingDock.\(id).edge" }
    private static func fractionKey(_ id: String) -> String { "FloatingDock.\(id).fraction" }

    func center(in area: CGRect, itemSize: CGSize) -> CGPoint {
        let minX = area.minX + itemSize.width / 2
        let maxX = max(minX, area.maxX - itemSize.width / 2)
        let minY = area.minY + itemSize.height / 2
        let maxY = max(minY, area.maxY - itemSize.height / 2)
        switch edge {
        case .leading: return CGPoint(x: minX, y: minY + (maxY - minY) * fraction)
        case .trailing: return CGPoint(x: maxX, y: minY + (maxY - minY) * fraction)
        case .top: return CGPoint(x: minX + (maxX - minX) * fraction, y: minY)
        case .bottom: return CGPoint(x: minX + (maxX - minX) * fraction, y: maxY)
        }
    }

    /// Prefers the side edges, and docks to the top or bottom only near them.
    static func nearest(to point: CGPoint, in area: CGRect, itemSize: CGSize) -> DockPosition {
        let left = point.x - area.minX
        let right = area.maxX - point.x
        let top = point.y - area.minY
        let bottom = area.maxY - point.y
        let side = min(left, right)
        let verticalThreshold = itemSize.height * 1.5

        let edge: Edge
        if top < verticalThreshold && top < side {
            edge = .top
        } else if bottom < verticalThreshold && bottom < side {
            edge = .bottom
        } else {
            edge = left < right ? .leading : .trailing
        }

        let fraction: CGFloat
        switch edge {
        case .leading, .trailing:
            let span = max(1, area.height - itemSize.height)
            fraction = (point.y - area.minY - itemSize.height / 2) / span
        case .top, .bottom:
            let span = max(1, area.width - itemSize.width)
            fraction = (point.x - area.minX - itemSize.width / 2) / span
        }
        return DockPosition(edge: edge, fraction: min(max(fraction, 0), 1))
    }
}

final class DockButton: UIView {
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let ring = UIView()
    private let imageView = UIImageView()

    init(id: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)

        blur.layer.cornerRadius = 16
        blur.layer.cornerCurve = .continuous
        blur.clipsToBounds = true
        blur.isUserInteractionEnabled = false
        addSubview(blur)

        ring.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        ring.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        ring.layer.borderWidth = 2
        ring.isUserInteractionEnabled = false
        addSubview(ring)

        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        addSubview(imageView)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "FloatingDock.\(id).button"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blur.frame = bounds
        let ringSide = bounds.width * 0.66
        ring.bounds.size = CGSize(width: ringSide, height: ringSide)
        ring.center = CGPoint(x: bounds.midX, y: bounds.midY)
        ring.layer.cornerRadius = ringSide / 2
        imageView.frame = ring.frame.insetBy(dx: 8, dy: 8)
    }

    func setSymbol(_ name: String) {
        imageView.image = UIImage(systemName: name)
    }
}

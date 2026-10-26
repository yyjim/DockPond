import SwiftUI
import UIKit

/// Finds the window scene that hosts the modified view, and keeps a dock window in
/// that scene. The scene comes from the view itself, so each scene of a
/// multi-window app gets its own dock.
struct DockInstaller: UIViewRepresentable {
    let content: DockContent
    let configuration: FloatingDockConfiguration

    func makeCoordinator() -> DockWindowController {
        DockWindowController(configuration: configuration)
    }

    func makeUIView(context: Context) -> SceneProbeView {
        let view = SceneProbeView()
        view.isUserInteractionEnabled = false
        let controller = context.coordinator
        view.onSceneChange = { controller.attach(to: $0) }
        return view
    }

    func updateUIView(_ view: SceneProbeView, context: Context) {
        context.coordinator.update(content)
    }

    static func dismantleUIView(_ view: SceneProbeView, coordinator: DockWindowController) {
        coordinator.detach()
    }
}

final class SceneProbeView: UIView {
    var onSceneChange: ((UIWindowScene?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onSceneChange?(window?.windowScene)
    }
}

@MainActor
final class DockWindowController {
    private let configuration: FloatingDockConfiguration
    private let model = DockModel()
    /// A plain copy of `model.content`. `update(_:)` runs inside `updateUIView`,
    /// where SwiftUI records every observable read as a dependency, so reading the
    /// model there and then writing it loops forever.
    private var content = DockContent()
    private var window: DockWindow?
    private var viewController: DockViewController?

    init(configuration: FloatingDockConfiguration) {
        self.configuration = configuration
    }

    func attach(to scene: UIWindowScene?) {
        guard let scene, window?.windowScene !== scene else { return }
        detach()

        model.scene = scene
        let viewController = DockViewController(model: model, configuration: configuration)
        viewController.updateButton(title: content.title, systemImage: content.systemImage)
        let window = DockWindow(windowScene: scene)
        window.windowLevel = configuration.windowLevel
        window.backgroundColor = .clear
        window.rootViewController = viewController
        if configuration.closesOnOutsideTap {
            window.onOutsideTouch = { [weak viewController] in viewController?.setExpanded(false) }
        }
        window.isHidden = !content.isPresented
        self.window = window
        self.viewController = viewController
    }

    func update(_ newContent: DockContent) {
        let previous = content
        content = newContent
        model.content = newContent

        if newContent.isPresented != previous.isPresented {
            if !newContent.isPresented {
                viewController?.setExpanded(false, animated: false)
            }
            window?.isHidden = !newContent.isPresented
        }
        if newContent.title != previous.title || newContent.systemImage != previous.systemImage {
            viewController?.updateButton(title: newContent.title, systemImage: newContent.systemImage)
        }
    }

    func detach() {
        window?.isHidden = true
        window = nil
        viewController = nil
    }
}

/// Passes through every touch that does not land on the button or the panel.
final class DockWindow: UIWindow {
    var onOutsideTouch: (() -> Void)?

    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        guard hit == nil || hit === rootViewController?.view else { return hit }
        if event?.type == .touches, let onOutsideTouch {
            Task { @MainActor in onOutsideTouch() }
        }
        return nil
    }
}

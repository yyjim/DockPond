#if canImport(UIKit) && !os(watchOS)
import SwiftUI
import UIKit

/// A window that shows the tweaks UI when you shake the device.
open class TweaksWindow: UIWindow {
    private let tweaks: [any AnyTweak]
    private let store: TweakStore
    private weak var presentedTweaks: UIViewController?

    public init(windowScene: UIWindowScene, tweaks: [any AnyTweak], store: TweakStore = .shared) {
        self.tweaks = tweaks
        self.store = store
        super.init(windowScene: windowScene)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake, store.isEnabled else {
            return super.motionEnded(motion, with: event)
        }
        presentTweaks()
    }

    public func presentTweaks() {
        guard presentedTweaks?.presentingViewController == nil, var presenter = rootViewController else { return }
        while true {
            if presenter.view.containsTweaksPresence { return }
            guard let presented = presenter.presentedViewController else { break }
            presenter = presented
        }
        let controller = UIHostingController(rootView: TweaksView(tweaks) { [weak presenter] in
            presenter?.dismiss(animated: true)
        })
        presenter.present(controller, animated: true)
        presentedTweaks = controller
    }
}

/// Lets `TweaksWindow` find a `TweaksView` that the app shows itself, for example
/// with `.sheet`. `presentedTweaks` covers the controller that this window presents,
/// because SwiftUI adds the marker only after its first render.
struct TweaksPresenceMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> TweaksPresenceView {
        TweaksPresenceView()
    }

    func updateUIView(_ view: TweaksPresenceView, context: Context) {}
}

final class TweaksPresenceView: UIView {}

private extension UIView {
    var containsTweaksPresence: Bool {
        self is TweaksPresenceView || subviews.contains { $0.containsTweaksPresence }
    }
}
#endif

#if canImport(UIKit) && !os(watchOS)
import SwiftUI
import UIKit

/// A window that shows the tweaks UI when you shake the device.
open class TweaksWindow: UIWindow {
    private let tweaks: [any AnyTweak]
    private let store: TweakStore

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
        var presenter = rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        guard let presenter, !(presenter is UIHostingController<TweaksView>) else { return }
        let controller = UIHostingController(rootView: TweaksView(tweaks) { [weak presenter] in
            presenter?.dismiss(animated: true)
        })
        presenter.present(controller, animated: true)
    }
}
#endif

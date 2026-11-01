import SwiftUI
import TweakDock
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        if ProcessInfo.processInfo.arguments.contains("-resetTweaks") {
            StudioTweaks.tweakStore.resetAll()
        }
        let window = TweaksWindow(windowScene: windowScene, tweaks: StudioTweaks.allTweaks, store: StudioTweaks.tweakStore)
        window.rootViewController = UIHostingController(rootView: PondRoot(tweaksWindow: window))
        window.makeKeyAndVisible()
        self.window = window
    }
}

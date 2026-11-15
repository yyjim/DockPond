import Combine
import Foundation
import TweakDock

/// Takes the place of Firebase Remote Config. It keeps the activated values in `UserDefaults`, as Remote Config does.
final class DemoRemoteConfig: TweakValueProvider, @unchecked Sendable {
    let name = "Remote"
    private let storageKey = "DemoRemoteConfig"
    private let subject = PassthroughSubject<Void, Never>()

    var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        (UserDefaults.standard.dictionary(forKey: storageKey)?[key] as? String).flatMap { TweakPrimitive(string: $0, as: kind) }
    }

    func activate(_ values: [String: String]?) {
        UserDefaults.standard.set(values, forKey: storageKey)
        subject.send()
    }
}

enum DemoSources {
    static let remoteConfig = DemoRemoteConfig()

    /// Remote Config sends text. `exp_onboarding` has an unknown variant, and `exp_share_sheet` is not in it.
    static let fetchedValues = [
        "exp_paywall_layout": "B",
        "exp_onboarding": "Z",
        "exp_ipad_sidebar": "B",
    ]

    static func fetchRemoteConfig() {
        remoteConfig.activate(fetchedValues)
    }

    static func clearRemoteConfig() {
        remoteConfig.activate(nil)
    }
}

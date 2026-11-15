import TweakDock

/// An in-memory "Remote" source takes the place of Firebase Remote Config.
enum DemoSources {
    /// Remote Config sends text. `exp_onboarding` has an unknown variant, and `exp_share_sheet` is not in it.
    static let fetchedValues: [String: TweakPrimitive] = [
        "exp_paywall_layout": .string("B"),
        "exp_onboarding": .string("Z"),
        "exp_ipad_sidebar": .string("B"),
        "upload_limit": .string("12"),
    ]

    static func fetchRemoteConfig() {
        DemoTweaks.tweakStore.remote = InMemoryValueProvider(name: "Remote", values: fetchedValues)
    }

    static func clearRemoteConfig() {
        DemoTweaks.tweakStore.remote = nil
    }
}

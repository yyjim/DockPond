import TweakDock
import UIKit

/// The sources of the experiment tweaks. An in-memory "Remote" source takes the place of Firebase Remote Config.
enum DemoSources {
    static let localSplit = LocalSplitTweakSource(splits: [
        "lab_card_style": .variants(["A": 50, "B": 50]),
        "rollout_new_badge": .rollout(0.5),
    ])

    /// Remote Config sends text. `exp_onboarding` has an unknown variant, and `exp_share_sheet` is not in it.
    static let fetchedValues: [String: TweakPrimitive] = [
        "exp_paywall_layout": .string("B"),
        "exp_onboarding": .string("Z"),
        "exp_ipad_sidebar": .string("B"),
        "upload_limit": .string("12"),
    ]

    @MainActor
    static func make(remoteValues: [String: TweakPrimitive] = [:]) -> any TweakSource {
        CombinedTweakSource([
            LaunchArgumentTweakSource(),
            DeviceTweakSource(
                CombinedTweakSource([InMemoryTweakSource(name: "Remote", values: remoteValues), localSplit]),
                devices: ["exp_ipad_sidebar": [.pad]]
            ),
        ])
    }

    @MainActor
    static func fetchRemoteConfig() {
        DemoTweaks.tweakStore.source = make(remoteValues: fetchedValues)
    }

    @MainActor
    static func clearRemoteConfig() {
        DemoTweaks.tweakStore.source = make()
    }
}

# TweakDock sources

A source gives values to tweaks, for example from Remote Config, a local split, or launch arguments.
Use sources to run experiments and remote config with the same `@Tweak` properties.

## Read a value from a source

A tweak with a `sourceKey` reads its value from `TweakStore.source`.
The store finds the value in this order:

1. The override that you set in the tweaks UI or in code. The store ignores overrides when `isEnabled` is `false`.
2. The source value, when it is valid.
3. The default value.

```swift
@Tweaks
enum AppTweaks {
    enum Paywall: String, CaseIterable, TweakValue { case A, B, C }

    @Tweak(collection: "Experiments", group: "Remote", name: "Paywall", defaultValue: Paywall.A, sourceKey: "exp_paywall")
    static var paywall: Paywall
}

AppTweaks.tweakStore.source = CombinedTweakSource([
    LaunchArgumentTweakSource(),                                   // -tweak.exp_paywall B, for UI tests
    DeviceTweakSource(firebase, devices: ["exp_ipad_only": [.pad]]),
    LocalSplitTweakSource(splits: ["lab_new_badge": .rollout(0.1)]),
])

AppTweaks.paywallTweak.currentValue   // .default(.A), .source("Firebase", .B), or .override(.C)
```

The store uses a source value only when it is valid.
An unknown enum case, a value out of `min...max`, a value that is not in `options`, or text of the wrong kind gives the default value.
Use `currentValue` to report experiments to analytics:

| Case | `currentValue` | User property |
| --- | --- | --- |
| The source value is present and valid | `.source("Firebase", .B)` | `B` |
| The key is not fetched yet (first launch) | `.default(.A)` | `"default"` |
| The key is not in the source | `.default(.A)` | `"default"` |
| The value is not a known variant | `.default(.A)` | `"default"` |
| The device is not in `devices` | `.default(.A)` | `"default"` |

```swift
let userProperty = switch AppTweaks.paywallTweak.currentValue {
case .default: "default"
case let .source(_, value), let .override(value): value.rawValue
}
```

`currentValuePublisher` publishes `currentValue`, then each change.

TweakDock has these sources. None of them need a dependency.

| Source | Use |
| --- | --- |
| `CombinedTweakSource` | Asks each source in order, and uses the first value. `.source` gives the name of the inner source. |
| `DeviceTweakSource` | Gives the values of its base source only on the given devices. |
| `LocalSplitTweakSource` | Puts each device in a local bucket for an experiment or a rollout that has no server. |
| `LaunchArgumentTweakSource` | Reads `-tweak.<key> <value>` launch arguments. |
| `InMemoryTweakSource` | Keeps values in memory, for tests, previews, or a fake remote config. |

In the tweaks UI, a tweak with a `sourceKey` shows where its value comes from under its name.
To remove an override, swipe the row, or select "Use <source>" in the options.

## Firebase Remote Config

TweakDock does not depend on Firebase. Add this adapter to your app:

```swift
import FirebaseRemoteConfig
import TweakDock

final class FirebaseTweakSource: TweakSource, @unchecked Sendable {
    let name = "Firebase"
    private let remoteConfig: RemoteConfig

    init(remoteConfig: RemoteConfig = .remoteConfig()) {
        self.remoteConfig = remoteConfig
    }

    func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        let value = remoteConfig.configValue(forKey: key)
        // `.static` means not activated yet or not in Remote Config. `.default` is a `setDefaults` value.
        guard value.source == .remote else { return nil }
        return TweakPrimitive(string: value.stringValue, as: kind)
    }
}

AppTweaks.tweakStore.source = FirebaseTweakSource()   // After FirebaseApp.configure().
```

The adapter only reads values. The app fetches and activates Remote Config, as before.
Until Remote Config activates, each sourced tweak gives its default value. After it activates, the next read gives the remote value.
Do not use `boolValue` or `numberValue`, because they return `false` or `0` for text that is not valid.
`TweakPrimitive(string:as:)` returns `nil` for that text, so the tweak uses its default value.

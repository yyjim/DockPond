# TweakDock sources

A source rule tells a tweak where to read its value: Remote Config or a local split.
Each `@Tweak` declares its whole experiment in one place: the key, the variants, the default value, the devices, and the source.

## Declare experiments

```swift
@Tweaks
enum Experiments {
    enum Paywall: String, CaseIterable, TweakValue { case A, B, C }
    enum CardStyle: String, CaseIterable, TweakValue { case A, B }

    // Remote Config, all devices
    @Tweak(collection: "Experiments", group: "Paywall", name: "Layout",
           defaultValue: Paywall.A, source: .remote("exp_paywall"))
    static var paywall: Paywall

    // Remote Config, iPhone only
    @Tweak(collection: "Experiments", group: "Recap", name: "Monthly Recap",
           defaultValue: Paywall.A, source: .remote("exp_monthly_recap", devices: [.phone]))
    static var monthlyRecap: Paywall

    // A local split, no server
    @Tweak(collection: "Experiments", group: "Home", name: "Card Style",
           defaultValue: CardStyle.A, source: .local("lab_card_style", .variants(["A": 50, "B": 50])))
    static var cardStyle: CardStyle

    // A local rollout: true on 10% of devices
    @Tweak(collection: "Experiments", group: "Home", name: "New Badge",
           defaultValue: false, source: .local("rollout_new_badge", .rollout(0.1)))
    static var showsNewBadge: Bool
}

// The only setup at launch, after FirebaseApp.configure().
Experiments.tweakStore.remote = FirebaseTweakSource()
```

`source` is optional. A tweak without it uses only its override and its default value.

## Where the value comes from

The store finds the value of a tweak in this order:

1. The override that you set in the tweaks UI or in code.
2. A launch argument `-tweak.<key> <value>`, for UI tests. It applies on all devices.
3. The declared source, on the devices in `devices`. `.remote` reads `TweakStore.remote`. `.local` computes the split.
4. The default value.

A value that is not valid goes to the next step. Examples: an unknown enum case, a value out of `min...max`, a value that is not in `options`, or text of the wrong kind.
When `isEnabled` is `false`, the store ignores overrides and launch arguments.

A write, such as `Experiments.paywall = .B`, saves an override, also when the value equals the source value.
The override hides later source values. Call `reset()` to use the source value again.

## Report experiments to analytics

Use `currentValue`:

| Case | `currentValue` | User property |
| --- | --- | --- |
| The source value is present and valid | `.source("Firebase", .B)` | `B` |
| The key is not fetched yet (first launch) | `.default(.A)` | `"default"` |
| The key is not in Remote Config | `.default(.A)` | `"default"` |
| The value is not a known variant | `.default(.A)` | `"default"` |
| The device is not in `devices` | `.default(.A)` | `"default"` |

```swift
let userProperty = switch Experiments.paywallTweak.currentValue {
case .default: "default"
case let .source(_, value), let .override(value): value.rawValue
}
```

`currentValuePublisher` publishes `currentValue`, then each change.
The source names are the name of `TweakStore.remote`, `"Local Split"`, and `"Launch Argument"`.

## Local splits

A local split gives each device a value without a server. The device keeps its value.

- `.variants(["A": 50, "B": 50])` gives each variant in proportion to its weight. The weights are relative, so `["A": 1, "B": 1]` is the same split. A variant can also be the text of a number or a Boolean value.
- `.rollout(0.1)` gives `true` to 10% of the devices. When you increase the fraction, the devices that had `true` keep it.
- Each key has its own value. If you change the weights of variants, some devices get a different value. To start an experiment again, use a new key.
- `tweakStore.resetSplits()` gives this device new values in all splits.

The value comes from a hash of the key and a random seed. The store keeps the seed in a file next to the tweaks file, so app extensions in the same app group get the same values.
A new install gets a new seed.

## Devices

`devices` is `.all` when you do not give it. Give it only to restrict an experiment: `.phone`, `.pad`, `.mac`, `.vision`, or `.tv`.
An iPhone app that runs on an iPad counts as `.pad`.
An override and a launch argument apply on all devices, so you can test an iPad experiment on an iPhone.

## Tests and previews

`InMemoryTweakSource` gives fixed values. Use it as `TweakStore.remote` in tests, previews, or a fake remote config.
To change the values, set a new source.

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

AppTweaks.tweakStore.remote = FirebaseTweakSource()   // After FirebaseApp.configure().
```

The adapter only reads values. The app fetches and activates Remote Config, as before.
Until Remote Config activates, each sourced tweak gives its default value. After it activates, the next read gives the remote value.
Do not use `boolValue` or `numberValue`, because they return `false` or `0` for text that is not valid.
`TweakPrimitive(string:as:)` returns `nil` for that text, so the tweak uses its default value.

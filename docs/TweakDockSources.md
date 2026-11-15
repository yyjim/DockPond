# TweakDock sources

Give `from:` in `@Tweak` to declare where a tweak reads its value.
Each `@Tweak` then holds its whole experiment in one place: the key, the variants, the default value, the devices, and the source.

## Declare experiments and config values

```swift
@Tweaks
enum Experiments {
    enum Paywall: String, CaseIterable, TweakValue { case A, B, C }
    enum CardStyle: String, CaseIterable, TweakValue { case A, B }

    // An A/B test in Remote Config, all devices
    @Tweak(collection: "Experiments", group: "Paywall", name: "Layout",
           defaultValue: Paywall.A, from: .experiment("exp_paywall"))
    static var paywall: Paywall

    // An A/B test in Remote Config, iPhone only
    @Tweak(collection: "Experiments", group: "Recap", name: "Monthly Recap",
           defaultValue: Paywall.A, from: .experiment("exp_monthly_recap", devices: [.phone]))
    static var monthlyRecap: Paywall

    // A plain value in Remote Config, not an experiment
    @Tweak(collection: "Config", group: "Upload", name: "Limit",
           defaultValue: 5, from: .config("upload_limit"))
    static var uploadLimit: Int

    // An A/B test with no server
    @Tweak(collection: "Experiments", group: "Home", name: "Card Style",
           defaultValue: CardStyle.A, from: .localExperiment("lab_card_style", ["A": 50, "B": 50]))
    static var cardStyle: CardStyle

    // A rollout: true on 10% of devices
    @Tweak(collection: "Features", group: "Home", name: "New Badge",
           defaultValue: false, from: .rollout("rollout_new_badge", 0.1))
    static var showsNewBadge: Bool
}

// The only setup at launch, after FirebaseApp.configure().
Experiments.tweakStore.remote = FirebaseValueProvider()
```

| `from:` | Reads | In `experimentProperties` |
| --- | --- | --- |
| `.experiment(key)` | `TweakStore.remote` | Yes |
| `.config(key)` | `TweakStore.remote` | No |
| `.localExperiment(key, weights)` | A local split | Yes |
| `.rollout(key, fraction)` | A local split of `true` and `false` | No |
| `.custom(key, provider)` | Your own `TweakValueProvider` | No |

Each case also takes `devices:`. `from:` is optional. A tweak without it uses only its override and its default value.

## Where the value comes from

The store finds the value of a tweak in this order:

1. The override that you set in the tweaks UI or in code.
2. A launch argument `-tweak.<key> <value>`, for UI tests. It applies on all devices.
3. The source in `from:`, on the devices in `devices`.
4. The default value.

A value that is not valid goes to the next step. Examples: an unknown enum case, a value out of `min...max`, a value that is not in `options`, or text of the wrong kind.
When `isEnabled` is `false`, the store ignores overrides and launch arguments.

A write, such as `Experiments.paywall = .B`, saves an override, also when the value equals the source value.
The override hides later source values. Call `reset()` to use the source value again.

`currentValue` tells where the value comes from: `.default(value)`, `.source(name, value)`, or `.override(value)`.
The source names are the name of the provider, `"Local Split"`, and `"Launch Argument"`.

## Report experiments to analytics

`experimentProperties` gives each `.experiment` and `.localExperiment` key, and the value to report.
It is read-only.

```swift
Analytics.setUserProperties(Experiments.allTweaks.experimentProperties)
// ["exp_paywall": "B", "exp_monthly_recap": "default", "lab_card_style": "A"]
```

| Case | `currentValue` | Reported value |
| --- | --- | --- |
| The source value is present and valid | `.source("Firebase", .B)` | `B` |
| The key is not fetched yet (first launch) | `.default(.A)` | `"default"` |
| The key is not in Remote Config | `.default(.A)` | `"default"` |
| The value is not a known variant | `.default(.A)` | `"default"` |
| The device is not in `devices` | `.default(.A)` | `"default"` |
| An override, in a debug build | `.override(.C)` | `C` |

## Local experiments and rollouts

They give each device a value without a server. The device keeps its value.

- `.localExperiment(key, ["A": 50, "B": 50])` gives each variant in proportion to its weight. The weights are relative, so `["A": 1, "B": 1]` is the same split. A variant can also be the text of a number or a Boolean value.
- `.rollout(key, 0.1)` gives `true` to 10% of the devices. When you increase the fraction, the devices that had `true` keep it.
- Each key has its own value. If you change the weights, some devices get a different value. To start an experiment again, use a new key.
- `tweakStore.resetSplits()` gives this device new values in all local experiments and rollouts.

The value comes from a hash of the key and a random seed. The store keeps the seed in a file next to the tweaks file, so app extensions in the same app group get the same values.
A new install gets a new seed.

## Devices

`devices` is `.all` when you do not give it. Give it only to restrict a tweak: `.phone`, `.pad`, `.mac`, `.vision`, or `.tv`.
An iPhone app that runs on an iPad counts as `.pad`.
An override and a launch argument apply on all devices, so you can test an iPad experiment on an iPhone.

## Your own provider

Use `.custom(key, provider)` for a value from another service, for example your own server.
The provider is a `TweakValueProvider`. When it sends `changes`, the tweak updates.

## Tests and previews

`InMemoryValueProvider` gives fixed values. Use it as `TweakStore.remote` in tests, previews, or a fake remote config.
To change the values, set a new provider.

## Firebase Remote Config

TweakDock does not depend on Firebase. Add this adapter to your app:

```swift
import FirebaseRemoteConfig
import TweakDock

final class FirebaseValueProvider: TweakValueProvider, @unchecked Sendable {
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

AppTweaks.tweakStore.remote = FirebaseValueProvider()   // After FirebaseApp.configure().
```

The adapter only reads values. The app fetches and activates Remote Config, as before.
Until Remote Config activates, each sourced tweak gives its default value. After it activates, the next read gives the remote value.
Do not use `boolValue` or `numberValue`, because they return `false` or `0` for text that is not valid.
`TweakPrimitive(string:as:)` returns `nil` for that text, so the tweak uses its default value.

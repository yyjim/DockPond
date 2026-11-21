# TweakDock experiments

Give `from: .experiment(key)` in `@Tweak` to read the value of a tweak from an A/B test service, such as Firebase Remote Config.
Each `@Tweak` then holds its whole experiment in one place: the key, the variants, the default value, and the devices.

## Declare experiments

```swift
@Tweaks(store: TweakStore(name: "Experiments", experimentProvider: FirebaseValueProvider.shared))
enum Experiments {
    enum Paywall: String, CaseIterable, TweakValue { case A, B, C }

    // All devices
    @Tweak(collection: "Experiments", group: "Paywall", name: "Layout",
           defaultValue: Paywall.A, from: .experiment("exp_paywall"))
    static var paywall: Paywall

    // iPhone only
    @Tweak(collection: "Experiments", group: "Recap", name: "Monthly Recap",
           defaultValue: Paywall.A, from: .experiment("exp_monthly_recap", devices: [.phone]))
    static var monthlyRecap: Paywall
}
```

The store gets `experimentProvider` when you make it, and keeps it.
Give the store its own `name`. Two stores with the same name use the same file, and each keeps its own copy of the overrides.
When `experimentProvider` is `nil`, each experiment uses its default value.
`from:` is optional. A tweak without it uses only its override and its default value.

## Where the value comes from

The store finds the value of a tweak in this order:

1. The override that you set in the tweaks UI or in code.
2. A launch argument `-tweak.<key> <value>`, for UI tests. It applies on all devices.
3. The value of `key` in `experimentProvider`, on the devices in `devices`.
4. The default value.

A value that is not valid goes to the next step. Examples: an unknown enum case, a value out of `min...max`, a value that is not in `options`, or text of the wrong kind.
When `isEnabled` is `false`, the store ignores overrides and launch arguments.

A write, such as `Experiments.paywall = .B`, saves an override, also when the value equals the provider value.
The override hides later provider values. Call `reset()` to use the provider value again.

`currentValue` tells where the value comes from: `.default(value)`, `.source(name, value)`, or `.override(value)`.
The source name is the name of the provider, or `"Launch Argument"`.

## Report experiments to analytics

`experimentProperties` gives each experiment key, and the value to report.
It is read-only.

```swift
Analytics.setUserProperties(Experiments.allTweaks.experimentProperties)
// ["exp_paywall": "B", "exp_monthly_recap": "default"]
```

| Case | `currentValue` | Reported value |
| --- | --- | --- |
| The provider value is present and valid | `.source("Firebase", .B)` | `B` |
| The key is not fetched yet (first launch) | `.default(.A)` | `"default"` |
| The key is not in Remote Config | `.default(.A)` | `"default"` |
| The value is not a known variant | `.default(.A)` | `"default"` |
| The device is not in `devices` | `.default(.A)` | `"default"` |
| An override, in a debug build | `.override(.C)` | `C` |

## Devices

`devices` is `.all` when you do not give it. Give it only to restrict an experiment: `.phone`, `.pad`, `.mac`, `.vision`, or `.tv`.
`.phone` contains `.standardPhone` and `.foldablePhone`, such as iPhone Duo. Give one of them to restrict an experiment to that kind of iPhone.

```swift
from: .experiment("exp_split_view", devices: [.foldablePhone, .pad])   // large screens
from: .experiment("exp_compact_tabs", devices: [.standardPhone])       // iPhone, not iPhone Duo
```

An iPhone app that runs on an iPad counts as `.pad`.
An override and a launch argument apply on all devices, so you can test an iPad experiment on an iPhone.

## Tests and previews

`InMemoryValueProvider` gives fixed values. Give it to `TweakStore` as `experimentProvider` in tests and previews.

## Firebase Remote Config

TweakDock does not depend on Firebase. Add this adapter to your app:

```swift
import Combine
import FirebaseCore
import FirebaseRemoteConfig
import TweakDock

// PassthroughSubject is not Sendable. The class is safe to share because only the main thread calls didActivate().
final class FirebaseValueProvider: TweakValueProvider, @unchecked Sendable {
    static let shared = FirebaseValueProvider()
    let name = "Firebase"
    private let subject = PassthroughSubject<Void, Never>()

    var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        // A tweak can be read before FirebaseApp.configure(), and RemoteConfig.remoteConfig() raises an exception then.
        guard FirebaseApp.app() != nil else { return nil }
        let value = RemoteConfig.remoteConfig().configValue(forKey: key)
        // `.static` means not activated yet or not in Remote Config. `.default` is a `setDefaults` value.
        guard value.source == .remote else { return nil }
        return TweakPrimitive(string: value.stringValue, as: kind)
    }

    /// Call it on the main thread after Remote Config activates.
    func didActivate() {
        subject.send()
    }
}
```

The adapter only reads values. The app fetches and activates Remote Config, as before.
Until Remote Config activates, each experiment gives its default value. After it activates, the next read gives the remote value.
Call `didActivate()` after activation, so that `publisher`, `currentValuePublisher`, and the tweaks UI update.
The publishers send on the thread that sends `changes`. Send `changes` on the main thread, or use `receive(on:)` in the subscriber.
Do not use `boolValue` or `numberValue`, because they return `false` or `0` for text that is not valid.
`TweakPrimitive(string:as:)` returns `nil` for that text, so the tweak uses its default value.

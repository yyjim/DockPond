# TweakDock experiments

A tweak with `from: .experiment(key)` reads its value from an A/B test service, such as Firebase Remote Config.
The debug UI can override the value. Write the experiments by hand, or generate them from YAML with the `tweakdock` gem.

## Where the value comes from

1. The override from the tweaks UI or from code.
2. The launch argument `-tweak.<key> <value>`. It applies on all devices.
3. The value of `key` from `experimentProvider`, on the devices in `devices`.
4. The default value.

A value that is not valid goes to the next step: an unknown enum case, a number out of range, or text of the wrong kind.

## Declare by hand

```swift
extension TweakStore {
    static let experiments = TweakStore(name: "Experiments", experimentProvider: FirebaseValueProvider.shared)
}

@Tweaks(store: .experiments)
enum Experiments {
    enum Paywall: String, CaseIterable, TweakValue { case A, B, C }

    @Tweak(collection: "Experiments", group: "Paywall", name: "Layout",
           defaultValue: Paywall.A, from: .experiment("exp_paywall"))
    static var paywall: Paywall

    @Tweak(collection: "Experiments", group: "Sidebar", name: "iPad Sidebar",
           defaultValue: false, from: .experiment("exp_ipad_sidebar", devices: [.pad, .mac]))
    static var iPadSidebar: Bool
}

Experiments.paywall                    // The remote value when it is valid, else .A.
Experiments.paywallTweak.currentValue  // .default(.A), .source("Firebase", .B), or .override(.C)
```

- `devices`: `.all` (default), `.phone`, `.standardPhone`, `.foldablePhone`, `.pad`, `.mac`, `.vision`, `.tv`. An iPhone app on an iPad counts as `.pad`.
- Give the experiments store its own `name`, so it does not share `Tweaks.json` with `TweakStore.shared`.
- A write such as `Experiments.paywall = .B` saves an override. The override hides later remote values until `reset()`.

## Generate from YAML

Prefer this when the app has many experiments, or when the experiment list comes from another team.

1. Add the gem to the `Gemfile` of the app. Use the same tag as the DockPond package version:

   ```ruby
   gem "tweakdock", git: "https://github.com/yyjim/DockPond", tag: "0.6.0", glob: "gems/tweakdock/*.gemspec"
   ```

2. Write the YAML file:

   ```yaml
   output: Experiments.swift   # Relative to this file.
   store: .experiments         # Default: .shared.

   experiments:
     exp_paywall: [A, B, C]    # The first variant is the default.

     exp_ipad_sidebar:
       variants: [control, sidebar]
       default: sidebar
       devices: [pad, mac]

     lab_storage_upsell:
       variants: ["off", "on"]  # Quote on, off, yes, and no. Else YAML reads them as booleans.
       group: Lab
   ```

3. Generate and check:

   ```sh
   bundle exec tweakdock generate Experiments.yml   # Writes the Swift file.
   bundle exec tweakdock check Experiments.yml      # Fails when the Swift file is not up to date. Use it in CI.
   ```

File settings: `output` (necessary), `type` (default `Experiments`), `store` (default `.shared`), `collection` (default `Experiments`), `group` (default `A/B Tests`), `access` (`public` or internal).
Experiment settings: `variants` (necessary, each a Swift name), `default`, `devices` (`all` or a list of `phone`, `pad`, `mac`, `vision`, `tv`), `group`.

The key gives the Swift names: `exp_ipad_sidebar` gives the type `ExpIpadSidebar` and the property `Experiments.expIpadSidebar`.

Rules:

- Do not edit the generated Swift file. Change the YAML, and run `generate` again.
- Exclude the generated file from SwiftFormat and SwiftLint, because `check` compares it with the generated code.
- The app declares the store, for example `TweakStore.experiments`. The gem does not declare it.

## Firebase Remote Config adapter

TweakDock does not depend on Firebase. Add this adapter to the app:

```swift
import Combine
import FirebaseCore
import FirebaseRemoteConfig
import TweakDock

// PassthroughSubject is not Sendable. The class is safe because only the main thread calls didActivate().
final class FirebaseValueProvider: TweakValueProvider, @unchecked Sendable {
    static let shared = FirebaseValueProvider()
    let name = "Firebase"
    private let subject = PassthroughSubject<Void, Never>()

    var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        // RemoteConfig.remoteConfig() raises an exception before FirebaseApp.configure().
        guard FirebaseApp.app() != nil else { return nil }
        let value = RemoteConfig.remoteConfig().configValue(forKey: key)
        guard value.source == .remote else { return nil }
        return TweakPrimitive(string: value.stringValue, as: kind)
    }

    /// Call it on the main thread after Remote Config activates.
    func didActivate() { subject.send() }
}
```

- The app fetches and activates Remote Config. The adapter only reads values.
- Call `didActivate()` after activation, so that publishers and the tweaks UI update.
- Do not use `boolValue` or `numberValue`. They return `false` or `0` for text that is not valid.

## Analytics

```swift
Analytics.setUserProperties(Experiments.allTweaks.experimentProperties)
// ["exp_paywall": "B", "exp_ipad_sidebar": "default"]
```

The value is `"default"` when no valid remote value or override exists.

## Test a variant

```swift
let app = XCUIApplication()
app.launchArguments += ["-tweak.exp_paywall", "B"]
app.launch()
```

The launch argument applies on all devices. A disabled store ignores it.

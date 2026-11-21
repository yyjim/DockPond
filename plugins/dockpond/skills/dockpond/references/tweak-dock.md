# TweakDock

`import TweakDock`

TweakDock lets the user change values at runtime from a debug screen. Declare tweaks with macros.

## Declare tweaks

```swift
@Tweaks
enum AppTweaks {
    enum Size: String, CaseIterable, TweakValue { case small, medium, large }

    @Tweak(collection: "UI", group: "Theme", name: "Dark Mode", defaultValue: true)
    static var isDarkMode: Bool

    @Tweak(collection: "UI", group: "Font", name: "Font Size", min: 10, max: 40, defaultValue: 14)
    static var fontSize: CGFloat

    @Tweak(collection: "UI", group: "Appearance", name: "Theme", options: ["light", "dark"], defaultValue: "light")
    static var theme: String

    @Tweak(collection: "UI", group: "Appearance", name: "Size", defaultValue: Size.small)
    static var size: Size

    @Tweak(collection: "Debug", group: "Session", name: "Clear Cache")
    static func clearCache() { /* Runs when the user taps it. */ }
}
```

- Put `@Tweak` only in a `@Tweaks` enum, on a `static var` with a type and no value, or on a `static func`.
- Supported types: `Bool`, `Int`, `Double`, `CGFloat`, `String`, and `String`-backed `CaseIterable` enums that conform to `TweakValue`.
- `min:` and `max:` apply to number types. `options:` applies to `String`.
- `collection` and `group` set where the tweak shows in the UI. `name` is its label.
- The first build asks the user to trust the `TweakDockMacros` plugin in Xcode. On the command line, give `-skipMacroValidation`.

## Read and write

```swift
let size = AppTweaks.fontSize              // The current value.
AppTweaks.fontSize = 20                    // Saves an override.

AppTweaks.fontSizeTweak.publisher          // Sends the current value, then each change.
    .sink { size in /* ... */ }
    .store(in: &cancellables)

AppTweaks.fontSizeTweak.reset()            // Removes the override.
AppTweaks.tweakStore.resetAll()            // Removes all overrides of the store.
AppTweaks.clearCacheTweak()                // Runs an action tweak.
```

Each `@Tweak` adds a `<name>Tweak` peer. `@Tweaks` adds `allTweaks` and `tweakStore`.

## Show the UI

```swift
// SwiftUI
.sheet(isPresented: $showsTweaks) {
    TweaksView(AppTweaks.allTweaks) { showsTweaks = false }    // onDismiss shows a close button.
}

// UIKit: a shake shows the tweaks.
window = TweaksWindow(windowScene: windowScene, tweaks: AppTweaks.allTweaks)
(window as? TweaksWindow)?.presentTweaks()                      // Shows the tweaks without a shake.
```

A good pattern: open the tweaks from a FloatingDock action.

```swift
.floatingDock(title: "Dev Tools") {
    ToolsView()
} actions: {
    Button("Tweaks", systemImage: "slider.vertical.3") { showsTweaks = true }
}
```

## Stores

Without `store:`, a `@Tweaks` type uses `TweakStore.shared`. It saves overrides to `Application Support/TweakDock/Tweaks.json`.

```swift
extension TweakStore {
    static let appGroup = TweakStore(name: "Tweaks", appGroup: "group.com.example.app")   // Share with app extensions.
}

@Tweaks(store: .appGroup)
enum AppTweaks { ... }
```

- Declare each store one time, as a `static let`.
- Give each store a different `name`. Two stores with the same name use the same file.
- One `TweaksView` can show the tweaks of more than one store: `TweaksView(AppTweaks.allTweaks + Experiments.allTweaks)`.

## Release builds

```swift
#if !DEBUG
TweakStore.shared.isEnabled = false
TweakStore.appGroup.isEnabled = false      // Each custom store.
#endif
```

A disabled store ignores overrides and launch arguments. Each tweak returns its experiment value or its default value.

## Tests

- In tests and previews, give `InMemoryValueProvider(name:values:)` to a store as `experimentProvider`.
- An experiment tweak reads the launch argument `-tweak.<key> <value>`. Only tweaks with `from: .experiment(key)` read it. Refer to [experiments.md](experiments.md).

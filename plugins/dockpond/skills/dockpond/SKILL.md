---
name: dockpond
description: Adds and uses the DockPond Swift package in an iOS app. FloatingDock gives a floating debug button with a panel of tools. GaugeDock shows layout facts such as size classes, safe area, and the hinge. TweakDock gives runtime tweaks and A/B test experiments with the @Tweak macro. Use when the user asks for a debug panel, a floating dev-tools button, a layout inspector, runtime tweaks, feature flags in a debug screen, or experiments from YAML, or when the code imports FloatingDock, GaugeDock, or TweakDock.
---

# DockPond

DockPond is a Swift package with three libraries. This skill matches DockPond 0.6.x.
Requirements: iOS 17 or later, Swift 6. The hinge values need iOS 27.1 or later.

## Select the library

| The user wants | Library | Reference |
| --- | --- | --- |
| A floating button that opens a panel of debug tools or actions | FloatingDock | [floating-dock.md](references/floating-dock.md) |
| Window size, size classes, safe area, orientation, scale, or hinge facts, on screen or in code | GaugeDock | [gauge-dock.md](references/gauge-dock.md) |
| Values to change at runtime from a debug screen | TweakDock | [tweak-dock.md](references/tweak-dock.md) |
| A/B test variants from Firebase Remote Config or a YAML file | TweakDock + the `tweakdock` gem | [experiments.md](references/experiments.md) |

Read only the reference that you need. The libraries work together: a dock can show a GaugeDock tool and open the tweaks UI from an action.

## Install

1. Examine how the app gets packages: an Xcode project, a `Package.swift`, XcodeGen, or Tuist.
2. Add the package with the latest version: `.package(url: "https://github.com/yyjim/DockPond", from: "0.6.0")`.
3. Add only the products that the user needs: `FloatingDock`, `GaugeDock`, `TweakDock`. `GaugeDock` brings `FloatingDock`.
4. TweakDock uses a Swift macro. Xcode asks the user to trust the `TweakDockMacros` plugin. On the command line, give `-skipMacroValidation` to `xcodebuild`.

## Rules that agents often break

- Apply `.floatingDock` or `.gaugeDock` one time, to the root view of the scene. Do not apply it to a child view or to each screen.
- The dock panel is not in the view hierarchy of the app. It does not get custom environment values or environment objects. Give the tool view an `@Observable` model.
- In UIKit, keep a strong reference to `FloatingDockController`. Install it in `scene(_:willConnectTo:options:)`.
- A UIKit tool view must calculate its size with Auto Layout.
- Give each dock its own `id` when the app has more than one dock.
- Show debug docks and tweaks only in debug builds:
  - Set `isEnabled: false` on the dock in release builds.
  - Set `TweakStore.shared.isEnabled = false`, and the same for each custom store, in release builds.
- Do not edit, format, or lint a file that the `tweakdock` gem generates. Change the YAML file, and run `bundle exec tweakdock generate`.
- Do not use `.floatingDock` on macOS, watchOS, or tvOS targets. DockPond is iOS only.

## Verify

1. Build the app for an iOS Simulator.
2. In a UI test, find the dock with the accessibility identifiers `FloatingDock.<id>.button` and `FloatingDock.<id>.panel`. The default `id` is `"default"`, and `"gauge"` for a gauge dock.
3. To set the start position of the button in a UI test, give the launch arguments `-FloatingDock.<id>.edge leading` and `-FloatingDock.<id>.fraction 0.2`.
4. To test an experiment variant without the UI, give the launch argument `-tweak.<key> <value>`, for example `-tweak.exp_paywall B`.

## More

The full guide is the README: https://github.com/yyjim/DockPond#readme

# GaugeDock

`import GaugeDock`

GaugeDock measures the layout of a window. It shows the values in a floating dock, and the app can read them in code.
GaugeDock shows facts only. The app makes its own layout decisions.

## Show the gauge dock

```swift
RootView().gaugeDock()                                         // SwiftUI

let gauge = LayoutGauge()                                      // UIKit
gauge.attach(to: window)
let dock = FloatingDockController.gaugeDock(gauge)
dock.install(in: windowScene)
self.dock = dock                                               // Keep a strong reference.
```

The dock title shows the size classes, for example "Regular · Compact". The panel shows these rows:

```
Window       951 × 669 pt · full screen
Screen       951 × 669 pt
Orientation  Landscape · right
Size class   H regular · V compact
Safe area    T 0 · L 59 · B 21 · R 59
Scale        3×
Hinge        Half Open · 92°                       ┐
Posture      Book                                  ├ only on a device with a hinge
Fold         Vertical at x 476 pt (estimated)      ┘
```

Options of `.gaugeDock(...)` and `FloatingDockController.gaugeDock(_:...)`:

| Option | Default | Use |
| --- | --- | --- |
| `isEnabled` | `true` | Set `false` in release builds. SwiftUI only. In UIKit, set `isEnabled` on the controller. |
| `sections` | `.all` | The rows: `.window`, `.orientation`, `.sizeClasses`, `.safeArea`, `.scale`, `.hinge`, `.fold`. |
| `systemImage` | `nil` | The dock icon. With `nil`, the icon follows the window orientation. |
| `configuration` | `FloatingDockConfiguration(id: "gauge")` | Refer to [floating-dock.md](floating-dock.md). |

The SwiftUI modifier also takes `actions:` and `label:`, as `.floatingDock` does.

## Put the gauge in another dock

```swift
@State private var gauge = LayoutGauge()

RootView()
    .layoutGauge(gauge)                         // Attaches the gauge to the window of this view.
    .floatingDock(title: "Dev Tools") {
        DockTool.layoutGauge(gauge)             // A tool with the gauge rows.
        DockTool("Controls", systemImage: "slider.horizontal.3") { ControlsView(model: model) }
    }
```

Use `LayoutGaugeView(gauge, sections:)` in SwiftUI or `LayoutGaugeUIView(gauge:sections:)` in UIKit to show the rows in your own view.

## Read the values in code

`LayoutGauge` is `@MainActor` and `@Observable`. Read `gauge.snapshot`:

| Property | Type |
| --- | --- |
| `windowSize`, `screenSize` | `CGSize` |
| `isResized` | `Bool`. `true` when the window is smaller than the screen. |
| `isLandscape` | `Bool` |
| `interfaceOrientation` | `UIInterfaceOrientation` |
| `horizontalSizeClass`, `verticalSizeClass` | `UIUserInterfaceSizeClass` |
| `safeAreaInsets` | `UIEdgeInsets` |
| `displayScale` | `CGFloat` |
| `hinge` | `Hinge?`: `state` (`.closed`, `.partiallyOpen`, `.fullyOpen`) and `angle`. `nil` without a hinge. |
| `fold` | `Fold?`: `posture` (`.closed`, `.flat`, `.book`, `.tabletop`), `axis` (`.vertical`, `.horizontal`), and `position` in window points. `nil` without a hinge. |

In UIKit, observe the changes, and keep the observation:

```swift
observation = gauge.observe { snapshot in
    layout(for: snapshot)
}
```

## Hinge and fold

- The hinge values need iOS 27.1 or later and a device with a hinge, such as iPhone Duo.
- iOS does not give the fold position. GaugeDock estimates it: the fold crosses the middle of the longer screen edge. The Fold row always says "estimated". Do not use `fold.position` for exact layout without a test on a real device.
- On a device without a hinge, `hinge` and `fold` are `nil`, and the rows do not show.

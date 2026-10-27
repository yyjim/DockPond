# DockPond plan

This file records the decisions, the current status, and the next steps for DockPond and its demo apps.

## Repository

- GitHub: https://github.com/yyjim/DockPond (public).
- `main` has the README, the licence, and `.gitignore`. PR #1 (`feat/dockpond-initial`) adds the code.
- Licence: MIT. Version: 0.1.0.
- Bundle IDs use the `io.github.yyjim.DockPondDemo` prefix.

| Path | Contents |
| --- | --- |
| `Sources/FloatingDock` | The floating dock: button, panel, tools, element tools, and the appearance tool. |
| `Sources/GaugeDock` | `LayoutGauge`: window, screen, orientation, size class, safe area, scale, hinge, and fold facts. |
| `Tests` | Unit tests for both products. |
| `DockPondDemo/DockPondDemo.xcodeproj` | The demo project. It uses the package at `..`. |
| `DockPondDemo/SwiftUIDemo` | The SwiftUI demo app. |
| `DockPondDemo/UIKitDemo` | The UIKit demo app ("DockPond UIKit"). |
| `DockPondDemo/Shared` | Types that both demo apps compile: `HingeState`, `FoldAxis`, `Posture`. |
| `DockPondDemo/SwiftUIDemoUITests` | UI tests for the SwiftUI demo. |

## Decisions

### Platform

- The package and the demos support iOS 17 and later.
- Put `#available(iOS 27.1, *)` around the hinge APIs (`DeviceHinge`, `UIHingeInteraction`).
- The package is not only for iPhone Duo. On a device without a hinge, do not show hinge or fold information.
- Support all orientations on iPhone. Face ID iPhones do not rotate upside down.
- Support SwiftUI and UIKit with the same features.

### FloatingDock

- The app installs a dock at launch. There is no switch in the app to remove it.
- The dock button moves like AssistiveTouch. It docks to the nearest edge. It saves its edge and position in `UserDefaults` (`FloatingDock.<id>.edge`, `FloatingDock.<id>.fraction`).
- An app can have more than one dock. Only one panel is open at a time in a window scene.
- A dock holds one or more `DockTool` values. `panelStyle` is `.tabs` or `.sections`.
- A panel with one tool shows no tabs and no section header.
- A tool can be a custom SwiftUI view, a custom UIKit view, or a ready-made tool (`.appearance()`, `.layoutGauge(_:)`).
- Element tools (`.toggle`, `.selector`, `.stepper`, `.slider`, `.button`) change one app value. The panel puts all element tools of a dock into one "General" tool. SwiftUI uses bindings. UIKit uses `get`/`set` closures.
- After any element changes a value, all elements read their values again. This keeps closure-backed UIKit values correct.
- Dock actions and tool actions close the panel. Controls in the panel do not close it.
- Accessibility identifiers include the dock id: `FloatingDock.<id>.button`, `FloatingDock.<id>.panel`.

### GaugeDock

- GaugeDock shows device facts only. The app makes layout decisions.
- iOS does not give the fold position. GaugeDock estimates it: the fold crosses the middle of the longer screen edge. The UI labels it "estimated".
- The fold section shows only on a device with a hinge.

### Demo apps

- SwiftUI demo: three docks. "Dev Tools" (tabs: General, Controls, Appearance), "Style" (element tools only), and the gauge dock.
- UIKit demo: two docks. "Dev Tools" (sections: Layout, General, Controls, Appearance) and "Style" (element tools only).
- The hinge history keeps the last 30 hinge state changes. Angle-only updates do not add rows.
- The SwiftUI split layout does not use `.inspector`. SwiftUI's inspector crashes `UISplitViewController` when the window resizes while it shows.

## Testing

- Use the Xcode MCP tools (`BuildProject`, `RunSomeTests`) when possible.
- Run the UI tests on the "iPhone Duo" simulator (iOS 27.1). Tests that need a hinge skip on other devices.
- Run only the tests that a change affects.
- Package unit tests: `xcodebuild test -scheme DockPond-Package -destination 'platform=iOS Simulator,name=iPhone Duo'`.

## Status

- Done: FloatingDock, GaugeDock, tools, panel styles, element tools, multiple docks, both demos, and the code review fixes.
- On 2026-10-26, all 7 dock UI tests passed from `DockPondDemo/` on the iPhone Duo simulator. The orientation test did not run.

## Next steps

1. Test the UIKit demo by hand: the Style dock, the live hinge history, and the sections panel.
2. Run the UI tests again after the rename to `SwiftUIDemo`, and run the orientation test.
3. Add a UI test target for the UIKit demo.
4. Update the design guide artifact (https://claude.ai/artifact/FBiv7hjUnsnM7NTfqRnShy). It shows the dock before tools existed.
5. Merge PR #1.

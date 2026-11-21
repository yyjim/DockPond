# FloatingDock

`import FloatingDock`

The dock shows a button in its own window above the app, also above sheets. The user drags the button to a screen edge. A tap opens a panel with tools and actions.

## SwiftUI

Apply the modifier one time, to the root view of the scene.

```swift
WindowGroup {
    RootView()
        .floatingDock(isEnabled: isDebug, title: "Dev Tools", systemImage: "wrench.and.screwdriver", panelStyle: .tabs) {
            DockTool("Controls", systemImage: "slider.horizontal.3") {
                ControlsView(model: model)          // Give an @Observable model. The panel gets no custom environment.
            } actions: {
                Button("Reset", systemImage: "arrow.counterclockwise") { model.reset() }
            }
            DockTool.appearance()                   // System, light, or dark appearance for the scene.
        } actions: {
            Button("Tweaks", systemImage: "slider.vertical.3") { showsTweaks = true }
        }
}
```

For one view, without tools, use `.floatingDock(title:systemImage:) { ToolsView() } actions: { ... }`.

A tool that must change the window scene can read the `floatingDockScene` environment value.

## UIKit

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var dock: FloatingDockController?           // Keep a strong reference.

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // ... make the window ...
        let dock = FloatingDockController(title: "Dev Tools", panelStyle: .sections, tools: [
            DockTool(title: "Controls", systemImage: "slider.horizontal.3", contentView: controlsView,
                     actions: [FloatingDockAction(title: "Reset", systemImage: "arrow.counterclockwise") { reset() }]),
            .appearance(),
        ])
        dock.actions = [FloatingDockAction(title: "About", systemImage: "info.circle") { showAbout() }]
        dock.install(in: windowScene)
        self.dock = dock
    }
}
```

- `contentView` must calculate its size with Auto Layout.
- `FloatingDockController(title:content:)` takes a SwiftUI view.
- `isEnabled`, `title`, `systemImage`, `panelStyle`, `tools`, `actions`, and `panelBackground` can change after `install(in:)`.
- Call `uninstall()` to remove the dock.

## Panel style

| `panelStyle` | Result |
| --- | --- |
| `.tabs` (default) | One tool at a time, with a tab for each tool. The tool actions show in the panel header. |
| `.sections` | All tools in one panel. Each tool has a header that collapses it. |

A panel with one tool shows no tabs and no section header.
Actions close the panel. Controls in a tool view do not close it.

## Element tools

Element tools change one app value without a custom view. The panel puts all element tools of a dock into one "General" tool.

```swift
.floatingDock(title: "Dev Tools") {
    DockTool.toggle("Grid", isOn: $settings.showsGrid)
    DockTool.selector("Theme", selection: $settings.theme, options: ["Ocean": .ocean, "Forest": .forest])
    DockTool.stepper("Columns", value: $settings.columns, in: 1...6)
    DockTool.slider("Speed", value: $settings.speed, in: 0...2)
    DockTool.button("Reset", systemImage: "arrow.counterclockwise") { settings.reset() }
}
```

In UIKit, give `get` and `set` closures:

```swift
dock.tools = [
    .toggle("Grid", get: { settings.showsGrid }, set: { settings.showsGrid = $0 }),
    .selector("Theme", options: ["Ocean", "Forest"], get: { settings.themeIndex }, set: { settings.themeIndex = $0 }),
]
```

A selector with four options or fewer shows segments. A selector with more options shows a menu.
`tint:` sets the color of a switch. `alignment: .leading` shows the switch next to its title.

## Configuration

`FloatingDockConfiguration` applies when you make the dock. Only `panelBackground` can change later.

| Option | Default | Use |
| --- | --- | --- |
| `id` | `"default"` | The key of the saved position and of the accessibility identifiers. Give each dock its own `id`. |
| `initialEdge`, `initialPosition` | `.trailing`, `0.7` | The start position. `initialPosition` is a fraction of the edge. |
| `buttonSize` | `60` | The button size. The touch area is never smaller than 44 points. |
| `idleDelay`, `idleOpacity` | 3 seconds, `0.45` | When the button fades, and how much. |
| `closesOnOutsideTap` | `true` | A tap outside the panel closes it. The app also gets that tap. |
| `windowLevel` | `.alert + 1` | The level of the dock window. |
| `tint` | `.primary` | The tint of actions, element controls, and tool content. |
| `panelBackground` | `.regular` | `.regular`, `.translucent`, or `.plain`. Add `.opacity(_:)`, for example `.translucent.opacity(0.7)`. |
| `panelSnapsToEdge` | `true` | A moved panel docks to the nearest edge. |

## Custom button

```swift
.floatingDock(title: "Tools", systemImage: "bird.fill") {
    ToolsView()
} label: { state in            // FloatingDockButtonState: edge, isDragging, isExpanded, isIdle
    Image("mascot")
        .rotationEffect(.degrees(state.isDragging ? 15 : 0))
        .animation(.spring, value: state)
}
```

In UIKit, call `dock.setButtonLabel { state in ... }`, and `removeButtonLabel()` to show the default button again.
The label does not receive touches. VoiceOver reads `title`.

## More than one dock

```swift
RootView()
    .floatingDock(title: "Tools", configuration: FloatingDockConfiguration(id: "tools")) { ToolsView() }
    .gaugeDock(configuration: FloatingDockConfiguration(id: "gauge", initialEdge: .leading))
```

Only one panel is open at a time in a window scene.

## UI tests

| Item | Value |
| --- | --- |
| Button | Accessibility identifier `FloatingDock.<id>.button` |
| Panel | Accessibility identifier `FloatingDock.<id>.panel` |
| Start edge | Launch arguments `-FloatingDock.<id>.edge leading` (`leading`, `trailing`, `top`, or `bottom`) |
| Start position | Launch arguments `-FloatingDock.<id>.fraction 0.2` |

```swift
let app = XCUIApplication()
app.launchArguments += ["-FloatingDock.default.edge", "trailing", "-FloatingDock.default.fraction", "0.2"]
app.launch()
app.buttons["FloatingDock.default.button"].tap()
XCTAssertTrue(app.descendants(matching: .any)["FloatingDock.default.panel"].waitForExistence(timeout: 2))
```

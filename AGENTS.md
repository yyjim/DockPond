# DockPond

DockPond is a Swift package with three iOS libraries: FloatingDock, GaugeDock, and TweakDock.
The README is the user guide. This file tells agents how to work in the repository.

## Repository

| Path | Contents |
| --- | --- |
| `Sources/FloatingDock` | The floating dock: button, panel, tools, element tools, and the appearance tool. |
| `Sources/GaugeDock` | `LayoutGauge` and the gauge dock. It depends on FloatingDock. |
| `Sources/TweakDock`, `Sources/TweakDockMacros` | The `@Tweak` and `@Tweaks` macros, `TweakStore`, `TweaksView`, and `TweaksWindow`. |
| `Tests` | Swift Testing tests for each library, and the macro tests. |
| `gems/tweakdock` | The Ruby gem that generates experiments from YAML. It uses only the Ruby standard library. |
| `DockPondDemo` | The demo project: `PondDemo`, `SwiftUIDemo`, `UIKitDemo`, `TweakDemo`, and their UI tests. |
| `plugins/dockpond` | The agent skill for apps that use DockPond. |
| `docs` | Extra guides and the README images. |
| `PLAN.md` | The design decisions and the status. Read the decisions before you change behavior. |

## Commands

Run `make help` to see all targets.

| Command | Use |
| --- | --- |
| `make test` | Unit tests of the three libraries on the iOS Simulator. |
| `make test-macros` | The macro tests. They run on macOS only. |
| `make test-gem` | The tweakdock gem tests. They also check `Tests/TweakDockTests/GeneratedExperiments.swift`. |
| `make demo-build` | Build the PondDemo app. |
| `make demo-test` | UI tests of SwiftUIDemo and TweakDemo. They are slow. |
| `make lint` | Check the format and lint of the outgoing Swift files. The pre-push hook runs it. |
| `make format` | Format and fix the outgoing and uncommitted Swift files. |
| `make verify` | `lint`, `test`, `test-macros`, `test-gem`, and `demo-build`. Run it before a PR. |

`scripts/simulator-destination` selects the simulator: an iPhone on the newest iOS runtime, and iPhone Duo when it is available.
Set `DESTINATION` to use a different one, for example `make test DESTINATION='platform=iOS Simulator,name=iPhone 17'`.
`swift build` and `swift test` do not work on macOS, because the libraries use UIKit. Use `make`.

## Rules

- Support iOS 17 and later, and Swift 6 strict concurrency.
- Put `#available(iOS 27.1, *)` around the hinge APIs (`DeviceHinge`, `UIHingeInteraction`).
- On a device without a hinge, do not show hinge or fold information.
- Give SwiftUI and UIKit the same features. Each public SwiftUI API needs a UIKit API.
- Use the `io.github.yyjim` prefix for bundle IDs and identifiers.
- Keep these keys stable, because apps and UI tests use them:
  - Accessibility identifiers `FloatingDock.<id>.button` and `FloatingDock.<id>.panel`.
  - `UserDefaults` keys `FloatingDock.<id>.edge`, `FloatingDock.<id>.fraction`, and `FloatingDock.<id>.tool`.
  - The launch argument `-tweak.<key> <value>`.
- Do not edit `Tests/TweakDockTests/GeneratedExperiments.swift`. Change the fixture in `gems/tweakdock/test/fixtures`, and generate the file again.
- Write tests with Swift Testing (`import Testing`). UI tests use XCTest.
- The Claude Code hook formats each Swift file that you write. Other agents must run `make format`.

## Documentation

- Write docs, comments, commit messages, and PR text in ASD-STE100 Simplified Technical English.
- When you change a public API, update these files in the same PR:
  - `README.md`, or the guide in `docs`.
  - The matching file in `plugins/dockpond/skills/dockpond/references`.
- When you release a version, update the version in the README install line, the gem README, and `plugins/dockpond/.claude-plugin/plugin.json`.

## Commits and PRs

- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `build:`, `style:`, `refactor:`, `test:`.
- Write the title in lower case after the type, for example `feat: move the open panel and set its background`.
- The PR body has the sections `# Description`, `# Test Plan`, and `# Screenshots`.

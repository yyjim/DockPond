import SwiftUI
import UIKit

extension DockTool {
    /// A tool that switches the scene between the system, light, and dark
    /// appearance. It sets `traitOverrides` on the window scene, so it changes
    /// every window in the scene, SwiftUI and UIKit alike.
    public static func appearance() -> DockTool {
        DockTool("Appearance", systemImage: "circle.lefthalf.filled", id: "appearance") {
            AppearanceToolView()
        }
    }
}

private struct AppearanceToolView: View {
    @Environment(\.floatingDockScene) private var scene
    @State private var style = UIUserInterfaceStyle.unspecified

    var body: some View {
        Picker("Appearance", selection: $style) {
            Text("System").tag(UIUserInterfaceStyle.unspecified)
            Text("Light").tag(UIUserInterfaceStyle.light)
            Text("Dark").tag(UIUserInterfaceStyle.dark)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .onAppear {
            if let scene, scene.traitOverrides.contains(UITraitUserInterfaceStyle.self) {
                style = scene.traitOverrides.userInterfaceStyle
            }
        }
        .onChange(of: style) { _, newStyle in
            guard let scene else { return }
            if newStyle == .unspecified {
                scene.traitOverrides.remove(UITraitUserInterfaceStyle.self)
            } else {
                scene.traitOverrides.userInterfaceStyle = newStyle
            }
        }
    }
}

extension EnvironmentValues {
    /// The window scene that shows the dock, for tools that change the scene.
    @Entry public var floatingDockScene: UIWindowScene?
}

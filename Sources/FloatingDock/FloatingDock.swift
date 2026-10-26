import SwiftUI
import UIKit

/// Options for a floating dock. They apply when the dock is created; later changes
/// are ignored.
public struct FloatingDockConfiguration {
    public enum Edge: String, Sendable {
        case leading, trailing, top, bottom
    }

    /// Keys the saved button position. Give each dock in an app its own id.
    public var id: String
    public var initialEdge: Edge
    /// Where the button starts along `initialEdge`, from 0 (top or leading) to 1.
    public var initialPosition: Double
    public var buttonSize: CGFloat
    /// How long the button stays fully visible after the last interaction.
    public var idleDelay: Duration
    public var idleOpacity: CGFloat
    /// Closes the panel when a touch lands outside it. The touch still reaches the app.
    public var closesOnOutsideTap: Bool
    public var windowLevel: UIWindow.Level

    public init(
        id: String = "default",
        initialEdge: Edge = .trailing,
        initialPosition: Double = 0.7,
        buttonSize: CGFloat = 60,
        idleDelay: Duration = .seconds(3),
        idleOpacity: CGFloat = 0.45,
        closesOnOutsideTap: Bool = true,
        windowLevel: UIWindow.Level = .alert + 1
    ) {
        self.id = id
        self.initialEdge = initialEdge
        self.initialPosition = initialPosition
        self.buttonSize = buttonSize
        self.idleDelay = idleDelay
        self.idleOpacity = idleOpacity
        self.closesOnOutsideTap = closesOnOutsideTap
        self.windowLevel = windowLevel
    }
}

extension View {
    /// Shows a floating button in a separate window above all app content,
    /// including sheets. Drag the button to dock it on any screen edge. Tap it to
    /// open a panel with the `tools`. Tap outside the panel, or tap an action, to
    /// close it.
    ///
    /// With more than one tool, `panelStyle` sets whether the panel shows them as
    /// tabs or as collapsible sections. `actions` always appear in the panel header.
    ///
    /// Apply it to the root view of a scene. Use `isEnabled` to decide at setup
    /// whether the dock exists, for example only in debug builds. A scene can
    /// show more than one dock; give each its own `configuration.id`.
    ///
    /// The panel renders outside this view's hierarchy, so tools do not inherit
    /// custom environment values. Give them an observable model to read, so they
    /// update without a render of the host view.
    public func floatingDock<Actions: View>(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        panelStyle: FloatingDockPanelStyle = .tabs,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @DockToolBuilder tools: () -> [DockTool],
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        background(
            DockInstaller(
                content: DockContent(
                    isPresented: isEnabled,
                    title: title,
                    systemImage: systemImage,
                    panelStyle: panelStyle,
                    tools: tools(),
                    actions: AnyView(actions())
                ),
                configuration: configuration
            )
        )
    }

    public func floatingDock(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        panelStyle: FloatingDockPanelStyle = .tabs,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @DockToolBuilder tools: () -> [DockTool]
    ) -> some View {
        floatingDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            panelStyle: panelStyle,
            configuration: configuration,
            tools: tools
        ) {
            EmptyView()
        }
    }

    /// Shows a floating dock with one view in its panel.
    public func floatingDock<Content: View, Actions: View>(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        let tool = DockTool(title, systemImage: systemImage, content: content)
        return floatingDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            configuration: configuration,
            tools: { tool },
            actions: actions
        )
    }

    public func floatingDock<Content: View>(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @ViewBuilder content: () -> Content
    ) -> some View {
        floatingDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            configuration: configuration,
            content: content
        ) {
            EmptyView()
        }
    }
}

struct DockContent {
    var isPresented = false
    var title = ""
    var systemImage = ""
    var panelStyle = FloatingDockPanelStyle.tabs
    var tools: [DockTool] = []
    var actions = AnyView(EmptyView())
}

@MainActor
@Observable
final class DockModel {
    var content = DockContent()
    @ObservationIgnored weak var scene: UIWindowScene?
}

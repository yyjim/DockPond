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
    /// The tint of the panel: its actions, its element controls, and the tool
    /// content. A view keeps its own tint if it sets one.
    public var tint: Color

    public init(
        id: String = "default",
        initialEdge: Edge = .trailing,
        initialPosition: Double = 0.7,
        buttonSize: CGFloat = 60,
        idleDelay: Duration = .seconds(3),
        idleOpacity: CGFloat = 0.45,
        closesOnOutsideTap: Bool = true,
        windowLevel: UIWindow.Level = .alert + 1,
        tint: Color = .primary
    ) {
        self.id = id
        self.initialEdge = initialEdge
        self.initialPosition = initialPosition
        self.buttonSize = buttonSize
        self.idleDelay = idleDelay
        self.idleOpacity = idleOpacity
        self.closesOnOutsideTap = closesOnOutsideTap
        self.windowLevel = windowLevel
        self.tint = tint
    }
}

/// The live state of a floating dock button. A custom button label receives it, so
/// that it can animate when the user drags the button or opens the panel.
public struct FloatingDockButtonState: Equatable, Sendable {
    /// The edge the button is docked to. During a drag, it is the edge the button
    /// docks to when the user releases it.
    public var edge: FloatingDockConfiguration.Edge
    public var isDragging: Bool
    /// The panel is open. The button fades out and shrinks while the panel shows.
    public var isExpanded: Bool
    /// The button is faded after `idleDelay` without interaction.
    public var isIdle: Bool

    public init(
        edge: FloatingDockConfiguration.Edge = .trailing,
        isDragging: Bool = false,
        isExpanded: Bool = false,
        isIdle: Bool = false
    ) {
        self.edge = edge
        self.isDragging = isDragging
        self.isExpanded = isExpanded
        self.isIdle = isIdle
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
        installDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            panelStyle: panelStyle,
            configuration: configuration,
            tools: tools(),
            actions: AnyView(actions()),
            label: nil
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
        floatingDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            configuration: configuration,
            content: content,
            actions: actions,
            optionalLabel: nil as (@MainActor (FloatingDockButtonState) -> EmptyView)?
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

    /// Shows a floating dock with a custom view as its button.
    ///
    /// `label` replaces the default button look. It receives the live button state,
    /// so it can animate during a drag, face away from its edge, or react when the
    /// panel opens. The dock keeps the drag, the edge snapping, and the tap. The
    /// label does not receive touches.
    ///
    /// VoiceOver reads `title`. `systemImage` shows in the panel header. The touch
    /// area is `configuration.buttonSize`, and never less than 44 points. The label
    /// can draw outside that area.
    public func floatingDock<Actions: View, Label: View>(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        panelStyle: FloatingDockPanelStyle = .tabs,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @DockToolBuilder tools: () -> [DockTool],
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder label: @escaping @MainActor (FloatingDockButtonState) -> Label
    ) -> some View {
        installDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            panelStyle: panelStyle,
            configuration: configuration,
            tools: tools(),
            actions: AnyView(actions()),
            label: DockButtonLabel(label)
        )
    }

    public func floatingDock<Label: View>(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        panelStyle: FloatingDockPanelStyle = .tabs,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @DockToolBuilder tools: () -> [DockTool],
        @ViewBuilder label: @escaping @MainActor (FloatingDockButtonState) -> Label
    ) -> some View {
        floatingDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            panelStyle: panelStyle,
            configuration: configuration,
            tools: tools,
            actions: { EmptyView() },
            label: label
        )
    }

    /// Shows a floating dock with one view in its panel and a custom view as its
    /// button.
    public func floatingDock<Content: View, Actions: View, Label: View>(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder label: @escaping @MainActor (FloatingDockButtonState) -> Label
    ) -> some View {
        floatingDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            configuration: configuration,
            content: content,
            actions: actions,
            optionalLabel: label
        )
    }

    public func floatingDock<Content: View, Label: View>(
        isEnabled: Bool = true,
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: @escaping @MainActor (FloatingDockButtonState) -> Label
    ) -> some View {
        floatingDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            configuration: configuration,
            content: content,
            actions: { EmptyView() },
            label: label
        )
    }

    package func floatingDock<Content: View, Actions: View, Label: View>(
        isEnabled: Bool,
        title: String,
        systemImage: String,
        configuration: FloatingDockConfiguration,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions,
        optionalLabel label: (@MainActor (FloatingDockButtonState) -> Label)?
    ) -> some View {
        installDock(
            isEnabled: isEnabled,
            title: title,
            systemImage: systemImage,
            panelStyle: .tabs,
            configuration: configuration,
            tools: [DockTool(title, systemImage: systemImage, content: content)],
            actions: AnyView(actions()),
            label: label.map { DockButtonLabel($0) }
        )
    }

    private func installDock(
        isEnabled: Bool,
        title: String,
        systemImage: String,
        panelStyle: FloatingDockPanelStyle,
        configuration: FloatingDockConfiguration,
        tools: [DockTool],
        actions: AnyView,
        label: DockButtonLabel?
    ) -> some View {
        background(
            DockInstaller(
                content: DockContent(
                    isPresented: isEnabled,
                    title: title,
                    systemImage: systemImage,
                    panelStyle: panelStyle,
                    tools: tools,
                    actions: actions,
                    label: label
                ),
                configuration: configuration
            )
        )
    }
}

struct DockButtonLabel {
    let body: @MainActor (FloatingDockButtonState) -> AnyView

    init<Label: View>(_ label: @escaping @MainActor (FloatingDockButtonState) -> Label) {
        body = { AnyView(label($0)) }
    }
}

struct DockContent {
    var isPresented = false
    var title = ""
    var systemImage = ""
    var panelStyle = FloatingDockPanelStyle.tabs
    var tools: [DockTool] = []
    var actions = AnyView(EmptyView())
    var label: DockButtonLabel?
}

@MainActor
@Observable
final class DockModel {
    var content = DockContent()
    var presentationCount = 0
    @ObservationIgnored weak var scene: UIWindowScene?
}

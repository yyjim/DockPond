import SwiftUI
import UIKit

/// A button in the panel header. Tapping it closes the panel, then runs `handler`.
public struct FloatingDockAction {
    public var title: String
    public var systemImage: String
    public var handler: @MainActor () -> Void

    public init(title: String, systemImage: String, handler: @escaping @MainActor () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.handler = handler
    }
}

/// The UIKit entry point to the floating dock. Create it once per scene, usually in
/// `scene(_:willConnectTo:options:)`, and call `install(in:)`.
///
///     let dock = FloatingDockController(title: "Dev Tools", panelStyle: .sections)
///     dock.tools = [
///         DockTool(title: "Controls", systemImage: "slider.horizontal.3", contentView: controlsView),
///         .appearance(),
///     ]
///     dock.install(in: windowScene)
///
/// Keep a strong reference for as long as the dock must stay on screen. A scene
/// can show more than one dock; give each its own `configuration.id`.
@MainActor
public final class FloatingDockController {
    public var title: String { didSet { apply() } }
    public var systemImage: String { didSet { apply() } }
    public var isEnabled = true { didSet { apply() } }
    public var panelStyle: FloatingDockPanelStyle { didSet { apply() } }
    public var tools: [DockTool] = [] { didSet { apply() } }
    /// Buttons that always appear in the panel header.
    public var actions: [FloatingDockAction] = [] { didSet { apply() } }

    private let windowController: DockWindowController

    public init(
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        panelStyle: FloatingDockPanelStyle = .tabs,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        tools: [DockTool] = []
    ) {
        self.title = title
        self.systemImage = systemImage
        self.panelStyle = panelStyle
        self.tools = tools
        self.windowController = DockWindowController(configuration: configuration)
    }

    /// Creates a dock with one SwiftUI view in its panel.
    public convenience init<Content: View>(
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            configuration: configuration,
            tools: [DockTool(title, systemImage: systemImage, content: content)]
        )
    }

    /// Creates a dock with one UIKit view in its panel. The view must size itself
    /// with Auto Layout.
    public convenience init(
        title: String,
        systemImage: String = "square.grid.2x2.fill",
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(),
        contentView: UIView
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            configuration: configuration,
            tools: [DockTool(title: title, systemImage: systemImage, contentView: contentView)]
        )
    }

    public func install(in scene: UIWindowScene) {
        apply()
        windowController.attach(to: scene)
    }

    public func uninstall() {
        windowController.detach()
    }

    private func apply() {
        windowController.update(DockContent(
            isPresented: isEnabled,
            title: title,
            systemImage: systemImage,
            panelStyle: panelStyle,
            tools: tools,
            actions: AnyView(ActionButtons(actions: actions))
        ))
    }
}

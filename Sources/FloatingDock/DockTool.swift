import SwiftUI
import UIKit

/// One tool in a floating dock panel: a title, an icon, a view, and optional
/// actions. A dock with more than one tool shows them as tabs or as sections,
/// as its `panelStyle` sets.
public struct DockTool: Identifiable {
    public let id: String
    public var title: String
    public var systemImage: String
    let content: AnyView
    let actions: AnyView
    let element: Element?

    /// Creates a tool from a SwiftUI view. The actions appear in the panel header
    /// while the tool is open (tabs), or in the tool's section header (sections).
    public init<Content: View, Actions: View>(
        _ title: String,
        systemImage: String,
        id: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.id = id ?? title
        self.title = title
        self.systemImage = systemImage
        self.content = AnyView(content())
        self.actions = AnyView(actions())
        self.element = nil
    }

    public init<Content: View>(
        _ title: String,
        systemImage: String,
        id: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, systemImage: systemImage, id: id, content: content) {
            EmptyView()
        }
    }

    /// Creates a tool from a UIKit view. The view must size itself with Auto Layout.
    @MainActor
    public init(
        title: String,
        systemImage: String,
        id: String? = nil,
        contentView: UIView,
        actions: [FloatingDockAction] = []
    ) {
        self.init(title, systemImage: systemImage, id: id) {
            HostedContentView(view: contentView)
        } actions: {
            ActionButtons(actions: actions)
        }
    }
}

/// How a dock panel shows more than one tool. A panel with one tool shows it
/// directly in both styles.
public enum FloatingDockPanelStyle: Sendable {
    /// One tool at a time, with a tab for each tool.
    case tabs
    /// All tools in one panel, each under a header that collapses it.
    case sections
}

@resultBuilder
public enum DockToolBuilder {
    public static func buildExpression(_ tool: DockTool) -> [DockTool] { [tool] }
    public static func buildExpression(_ tools: [DockTool]) -> [DockTool] { tools }
    public static func buildBlock(_ parts: [DockTool]...) -> [DockTool] { parts.flatMap { $0 } }
    public static func buildOptional(_ tools: [DockTool]?) -> [DockTool] { tools ?? [] }
    public static func buildEither(first tools: [DockTool]) -> [DockTool] { tools }
    public static func buildEither(second tools: [DockTool]) -> [DockTool] { tools }
    public static func buildArray(_ parts: [[DockTool]]) -> [DockTool] { parts.flatMap { $0 } }
    public static func buildLimitedAvailability(_ tools: [DockTool]) -> [DockTool] { tools }
}

struct ActionButtons: View {
    let actions: [FloatingDockAction]

    var body: some View {
        ForEach(actions.indices, id: \.self) { index in
            let action = actions[index]
            Button(action.title, systemImage: action.systemImage) { action.handler() }
        }
    }
}

struct HostedContentView: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fitting = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: fitting.height)
    }
}

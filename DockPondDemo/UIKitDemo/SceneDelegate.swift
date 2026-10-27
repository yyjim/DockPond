import FloatingDock
import GaugeDock
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var dock: FloatingDockController?
    private var styleDock: FloatingDockController?
    private let gauge = LayoutGauge()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let root = DuoRootViewController()
        let settings = root.settings
        let controls = TestControlsView()
        controls.onPrevious = { [weak root] in root?.selectPrevious() }
        controls.onNext = { [weak root] in root?.selectNext() }
        controls.showItem(root.selection)
        root.onSelectionChange = { [weak controls] in controls?.showItem($0) }

        let historyAction = FloatingDockAction(title: "History", systemImage: "clock.arrow.circlepath") { [weak root] in
            root?.showHistory()
        }
        let gauge = gauge
        let hingeStates: [HingeState?] = [nil, .closed, .partiallyOpen, .fullyOpen]
        let foldAxes: [FoldAxis?] = [nil, .vertical, .horizontal]
        let hingeElements: [DockTool] = [
            .selector("Hinge", options: ["Live", "Closed", "Half", "Flat"], get: {
                hingeStates.firstIndex(of: settings.stateOverride) ?? 0
            }, set: {
                settings.stateOverride = hingeStates[$0]
                settings.notifyChange()
            }),
            .selector("Fold axis", options: ["Auto", "Vertical", "Horizontal"], get: {
                foldAxes.firstIndex(of: settings.axisOverride) ?? 0
            }, set: {
                settings.axisOverride = foldAxes[$0]
                settings.notifyChange()
            }),
            .toggle("Fold line", get: { settings.showsFoldLine }, set: {
                settings.showsFoldLine = $0
                settings.notifyChange()
            }),
        ]
        func tools(hasHinge: Bool) -> [DockTool] {
            [.layoutGauge(gauge)] + (hasHinge ? hingeElements : []) + [
                DockTool(
                    title: "Controls",
                    systemImage: "slider.horizontal.3",
                    contentView: controls,
                    actions: hasHinge ? [historyAction] : []
                ),
                .appearance(),
            ]
        }

        let dock = FloatingDockController(
            title: "Dev Tools",
            systemImage: "wrench.and.screwdriver",
            panelStyle: .sections,
            configuration: FloatingDockConfiguration(id: "dev-tools-uikit"),
            tools: tools(hasHinge: false)
        )
        dock.actions = [
            FloatingDockAction(title: "About", systemImage: "info.circle") { [weak root] in root?.showAbout() },
        ]
        var hasHinge = false
        root.onStateChange = { [weak dock] state in
            guard let dock, hasHinge != state.hasHinge else { return }
            hasHinge = state.hasHinge
            dock.tools = tools(hasHinge: hasHinge)
        }
        self.dock = dock

        let styleDock = FloatingDockController(
            title: "Style",
            systemImage: "paintpalette",
            panelStyle: .sections,
            configuration: FloatingDockConfiguration(id: "style-uikit", initialPosition: 0.35),
            tools: [
                .selector("Fill", options: ["Solid", "Soft", "Mono"], get: {
                    SwatchStyle.current.fill.rawValue
                }, set: {
                    SwatchStyle.current.fill = SwatchStyle.Fill(rawValue: $0) ?? .solid
                }),
                .slider("Corners", in: 0...2, get: { SwatchStyle.current.cornerScale }, set: {
                    SwatchStyle.current.cornerScale = $0
                }),
                .toggle("Summaries", get: { SwatchStyle.current.showsSummaries }, set: {
                    SwatchStyle.current.showsSummaries = $0
                }),
                .stepper("Lines", in: 1...4, get: { SwatchStyle.current.summaryLines }, set: {
                    SwatchStyle.current.summaryLines = $0
                }),
                .button("Reset", systemImage: "arrow.counterclockwise") {
                    SwatchStyle.current = SwatchStyle()
                },
            ]
        )
        self.styleDock = styleDock

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        gauge.attach(to: window)
        dock.install(in: windowScene)
        styleDock.install(in: windowScene)
    }
}

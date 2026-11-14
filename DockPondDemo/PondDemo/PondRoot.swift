import FloatingDock
import GaugeDock
import SwiftUI
import TweakDock

enum Island: String, CaseIterable, Identifiable {
    case party, survey, studio

    var id: Self { self }

    var library: String {
        switch self {
        case .party: "FloatingDock"
        case .survey: "GaugeDock"
        case .studio: "TweakDock"
        }
    }

    var title: String {
        switch self {
        case .party: "Pool Party"
        case .survey: "Pool Survey"
        case .studio: "Duck Studio"
        }
    }

    var pitch: String {
        switch self {
        case .party: "Throw ducks in. Drag the float to any edge."
        case .survey: "Rotate, resize, or fold. The pool follows."
        case .studio: "Remix the duck while the app runs."
        }
    }

    var art: String { "island-\(rawValue)" }

    var fill: Color {
        switch self {
        case .party: .duck
        case .survey: .float
        case .studio: .bill
        }
    }

    var tilt: Double {
        switch self {
        case .party: -1.5
        case .survey: 1
        case .studio: -0.8
        }
    }
}

struct PondRoot: View {
    let presentTweaks: () -> Void
    @State private var gauge = LayoutGauge()
    @State private var path = Self.launchPath

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Island.self) { island in
                    switch island {
                    case .party: PoolPartyView()
                    case .survey: PoolSurveyView(gauge: gauge)
                    case .studio: DuckStudioView(openTweaks: presentTweaks)
                    }
                }
        }
        .tint(.bill)
        .layoutGauge(gauge)
        .floatingDock(
            title: "Lifeguard",
            systemImage: "lifepreserver",
            panelStyle: .sections,
            configuration: FloatingDockConfiguration(id: "lifeguard", initialEdge: .trailing, initialPosition: 0.82, tint: .bill)
        ) {
            DockTool.layoutGauge(gauge, sections: [.window, .sizeClasses, .safeArea, .fold])
            DockTool.appearance()
        } actions: {
            Button("Open Duck Studio tweaks", systemImage: "slider.horizontal.3") {
                presentTweaks()
            }
        } label: { state in
            LifebuoyLabel(state: state)
        }
    }

    private static var launchPath: [Island] {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-island"), index + 1 < arguments.count,
              let island = Island(rawValue: arguments[index + 1]) else { return [] }
        return [island]
    }
}

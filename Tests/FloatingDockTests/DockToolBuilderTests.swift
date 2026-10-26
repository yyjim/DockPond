import SwiftUI
import Testing
@testable import FloatingDock

@MainActor
struct DockToolBuilderTests {
    @DockToolBuilder
    private func tools(showsExtra: Bool, names: [String]) -> [DockTool] {
        DockTool("First", systemImage: "1.circle") { Text("1") }
        if showsExtra {
            DockTool("Extra", systemImage: "plus") { Text("+") }
        } else {
            DockTool("Fallback", systemImage: "minus") { Text("-") }
        }
        for name in names {
            DockTool(name, systemImage: "circle") { Text(name) }
        }
        DockTool.appearance()
    }

    @Test func buildsToolsInOrder() {
        #expect(tools(showsExtra: true, names: ["A", "B"]).map(\.id) == ["First", "Extra", "A", "B", "appearance"])
        #expect(tools(showsExtra: false, names: []).map(\.id) == ["First", "Fallback", "appearance"])
    }

    @Test func idDefaultsToTheTitle() {
        #expect(DockTool("Controls", systemImage: "slider.horizontal.3") { EmptyView() }.id == "Controls")
        #expect(DockTool("Controls", systemImage: "slider.horizontal.3", id: "c") { EmptyView() }.id == "c")
    }

    @Test func groupsElementToolsAtTheFirstElement() {
        let tools = DockTool.groupingElements([
            DockTool("Layout", systemImage: "ruler") { EmptyView() },
            .toggle("Grid", isOn: .constant(true)),
            DockTool.appearance(),
            .button("Reset") {},
        ])
        #expect(tools.map(\.id) == ["Layout", DockTool.elementsID, "appearance"])
        #expect(tools[1].title == DockTool.elementsTitle)
    }

    @Test func keepsToolsWithoutElements() {
        let tools = DockTool.groupingElements([DockTool.appearance()])
        #expect(tools.map(\.id) == ["appearance"])
    }
}

import SwiftUI

struct DockPanel: View {
    let model: DockModel
    let id: String
    let tint: Color
    let onClose: () -> Void
    @AppStorage private var selectedToolID: String
    @State private var collapsedToolIDs: Set<String> = []

    init(model: DockModel, id: String, tint: Color, onClose: @escaping () -> Void) {
        self.model = model
        self.id = id
        self.tint = tint
        self.onClose = onClose
        _selectedToolID = AppStorage(wrappedValue: "", "FloatingDock.\(id).tool")
    }

    var body: some View {
        let content = model.content
        let tools = DockTool.groupingElements(content.tools)
        let showsTabs = content.panelStyle == .tabs && tools.count > 1
        let selectedTool = tools.first { $0.id == selectedToolID } ?? tools.first

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: content.systemImage)
                Text(content.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer(minLength: 8)
                if tools.count == 1 || showsTabs, let selectedTool {
                    selectedTool.actions
                        .simultaneousGesture(TapGesture().onEnded(onClose))
                }
                content.actions
                    .simultaneousGesture(TapGesture().onEnded(onClose))
                Button("Close", systemImage: "xmark.circle.fill", action: onClose)
                    .foregroundStyle(.secondary)
            }
            .labelStyle(.iconOnly)
            .font(.title3)

            if showsTabs {
                Picker("Tool", selection: Binding(
                    get: { selectedTool?.id ?? "" },
                    set: { selectedToolID = $0 }
                )) {
                    ForEach(tools) { tool in
                        Text(tool.title).tag(tool.id)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }

            ViewThatFits(in: .vertical) {
                toolsBody(tools: tools, showsTabs: showsTabs, selectedTool: selectedTool)
                ScrollView {
                    toolsBody(tools: tools, showsTabs: showsTabs, selectedTool: selectedTool)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(tint)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 4)
        .environment(\.floatingDockScene, model.scene)
        .environment(\.dockPresentationCount, model.presentationCount)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("FloatingDock.\(id).panel")
    }

    @ViewBuilder
    private func toolsBody(tools: [DockTool], showsTabs: Bool, selectedTool: DockTool?) -> some View {
        if tools.count == 1 || showsTabs {
            selectedTool?.content
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(tools) { tool in
                    section(for: tool)
                    if tool.id != tools.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func section(for tool: DockTool) -> some View {
        let isCollapsed = collapsedToolIDs.contains(tool.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy) {
                        if isCollapsed {
                            collapsedToolIDs.remove(tool.id)
                        } else {
                            collapsedToolIDs.insert(tool.id)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                            .font(.caption2.bold())
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        Image(systemName: tool.systemImage)
                        Text(tool.title)
                    }
                    .font(.caption.bold())
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.title)
                .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
                Spacer(minLength: 8)
                tool.actions
                    .labelStyle(.iconOnly)
                    .simultaneousGesture(TapGesture().onEnded(onClose))
            }
            if !isCollapsed {
                tool.content
            }
        }
    }
}

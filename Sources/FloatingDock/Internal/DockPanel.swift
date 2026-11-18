import SwiftUI

struct DockPanel: View {
    let model: DockModel
    let id: String
    let tint: Color
    let onClose: () -> Void
    let onContentHeightChange: () -> Void
    let onHeaderDrag: (CGSize) -> Void
    let onHeaderDragEnd: (_ release: HeaderDragRelease?) -> Void
    @AppStorage private var selectedToolID: String
    @GestureState private var isDraggingHeader = false
    @State private var collapsedToolIDs: Set<String> = []

    init(
        model: DockModel,
        id: String,
        tint: Color,
        onClose: @escaping () -> Void,
        onContentHeightChange: @escaping () -> Void,
        onHeaderDrag: @escaping (CGSize) -> Void,
        onHeaderDragEnd: @escaping (HeaderDragRelease?) -> Void
    ) {
        self.model = model
        self.id = id
        self.tint = tint
        self.onClose = onClose
        self.onContentHeightChange = onContentHeightChange
        self.onHeaderDrag = onHeaderDrag
        self.onHeaderDragEnd = onHeaderDragEnd
        _selectedToolID = AppStorage(wrappedValue: "", "FloatingDock.\(id).tool")
    }

    /// A shorter drag is a slip of the finger on the header.
    static let headerDragMinimumDistance: CGFloat = 10

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
            .contentShape(.rect)
            .gesture(headerDrag)
            // A cancelled drag does not call onEnded.
            .onChange(of: isDraggingHeader) { _, isDragging in
                if !isDragging {
                    onHeaderDragEnd(nil)
                }
            }

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

            // Not ViewThatFits: its two copies of the tools share one UIKit content
            // view, and SwiftUI lays out the hidden copy off the main thread.
            ContentHeightLayout {
                ScrollView {
                    toolsBody(tools: tools, showsTabs: showsTabs, selectedTool: selectedTool)
                        // The preferred content size is the height with no width limit, so it does not
                        // change when only the line wrap at the panel width changes.
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in
                            onContentHeightChange()
                        }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(tint)
        .background { PanelBackgroundView(background: content.panelBackground) }
        // A material in a shape fill does not set this, and without it the
        // secondary styles in the panel lose their vibrancy.
        .environment(\.backgroundMaterial, content.panelBackground.material)
        .environment(\.floatingDockScene, model.scene)
        .environment(\.dockPresentationCount, model.presentationCount)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("FloatingDock.\(id).panel")
    }

    // The global space stays in place while the panel moves under the finger.
    private var headerDrag: some Gesture {
        DragGesture(minimumDistance: Self.headerDragMinimumDistance, coordinateSpace: .global)
            .updating($isDraggingHeader) { _, isDragging, _ in isDragging = true }
            .onChanged { onHeaderDrag($0.translation) }
            .onEnded { onHeaderDragEnd(HeaderDragRelease(translation: $0.translation, velocity: $0.velocity)) }
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

struct HeaderDragRelease {
    var translation: CGSize
    var velocity: CGSize
}

/// Draws the shadow only outside the shape, so that it does not darken a
/// background that the app shows through.
private struct PanelBackgroundView: View {
    let background: FloatingDockPanelBackground

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack {
            shape
                .fill(.black)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 4)
                .mask { OutsideOf(shape: shape).fill(style: FillStyle(eoFill: true)) }
            shape.fill(background.style)
        }
    }
}

private struct OutsideOf<Inner: Shape>: Shape {
    let shape: Inner
    let reach: CGFloat = 60

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -reach, dy: -reach))
        path.addPath(shape.path(in: rect))
        return path
    }
}

/// Sizes its one subview, a vertical scroll view, to the height of the content,
/// up to the proposed height.
private struct ContentHeightLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let ideal = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(ideal.height, proposal.height ?? .infinity))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

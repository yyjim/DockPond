import SwiftUI

/// Fully open (flat) and regular windows: a split view in portrait, and a split view
/// with an inspector column in landscape.
struct SplitLayout: View {
    @Binding var selection: Item?
    @Environment(\.duoContext) private var context
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(Item.samples, selection: $selection) { item in
                ItemRow(item: item)
                    .tag(item)
            }
            .navigationTitle("Gallery")
            .navigationSplitViewColumnWidth(min: 260, ideal: context.isLandscape ? 300 : 280)
        } detail: {
            if let selection {
                // SwiftUI's .inspector crashes UISplitViewController when the window resizes while it shows.
                HStack(spacing: 0) {
                    ItemDetailView(item: selection)
                    if showsInspector {
                        Divider()
                        ItemInspector(item: selection)
                            .frame(width: 260)
                    }
                }
            } else {
                ContentUnavailableView("Select a Place", systemImage: "square.split.2x1", description: Text("Pick an item in the sidebar."))
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var showsInspector: Bool {
        context.isLandscape && context.horizontalSizeClass == .regular && context.windowSize.width > 900
    }
}

private struct ItemInspector: View {
    let item: Item

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Title", value: item.title)
                LabeledContent("Symbol", value: item.symbol)
                LabeledContent("Hue", value: item.hue.formatted(.percent))
            }
            Section("Color") {
                ItemArtwork(item: item, cornerRadius: 12)
                    .frame(height: 120)
            }
        }
        .navigationTitle("Inspector")
    }
}

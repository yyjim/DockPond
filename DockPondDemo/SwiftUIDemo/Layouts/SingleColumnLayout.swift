import SwiftUI

/// Outer display (closed) and compact windows: a list in portrait, a grid in landscape.
struct SingleColumnLayout: View {
    @Binding var selection: Item?
    @Environment(\.duoContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                if context.isLandscape {
                    grid
                } else {
                    list
                }
            }
            .navigationTitle("Gallery")
            .navigationDestination(item: $selection) { item in
                ItemDetailView(item: item)
            }
        }
    }

    private var list: some View {
        List(Item.samples) { item in
            Button {
                selection = item
            } label: {
                ItemRow(item: item)
            }
            .tint(.primary)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                ForEach(Item.samples) { item in
                    Button {
                        selection = item
                    } label: {
                        ItemCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

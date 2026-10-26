import SwiftUI

/// Half open with a vertical fold: a two-page spread split exactly at the fold.
struct BookLayout: View {
    @Binding var selection: Item?
    @Environment(\.duoContext) private var context

    private var item: Item { selection ?? Item.samples[0] }

    var body: some View {
        let leftWidth = max(0, context.foldCenterInContent.x - DuoContext.foldGutter / 2)
        HStack(spacing: DuoContext.foldGutter) {
            leftPage
                .frame(width: leftWidth)
            rightPage
                .frame(maxWidth: .infinity)
        }
        .background(Color(.secondarySystemBackground))
        .animation(.smooth, value: item)
    }

    private var leftPage: some View {
        VStack(spacing: 16) {
            ItemArtwork(item: item, cornerRadius: 24)
                .aspectRatio(3 / 4, contentMode: .fit)
            Text("Page \(item.id * 2 + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
            pageButton("Previous", symbol: "chevron.left") { selection = item.previous }
        }
        .padding()
        .frame(maxHeight: .infinity)
        .background(.background, in: .rect(cornerRadius: 12))
    }

    private var rightPage: some View {
        VStack(spacing: 16) {
            ScrollView {
                ItemArticle(item: item)
                    .padding(.top)
            }
            Text("Page \(item.id * 2 + 2)")
                .font(.caption)
                .foregroundStyle(.secondary)
            pageButton("Next", symbol: "chevron.right") { selection = item.next }
        }
        .padding()
        .frame(maxHeight: .infinity)
        .background(.background, in: .rect(cornerRadius: 12))
    }

    private func pageButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

import SwiftUI

struct ItemArtwork: View {
    let item: Item
    var cornerRadius: CGFloat = 20
    @Environment(\.itemStyle) private var style

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius * style.cornerScale, style: .continuous)
            .fill(fill)
            .overlay {
                Image(systemName: item.symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 8)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .padding(cornerRadius)
            }
    }

    private var fill: AnyShapeStyle {
        switch style.fill {
        case .gradient: AnyShapeStyle(item.gradient)
        case .solid: AnyShapeStyle(item.color)
        case .mono: AnyShapeStyle(Color.gray)
        }
    }
}

struct ItemRow: View {
    let item: Item
    @Environment(\.itemStyle) private var style

    var body: some View {
        HStack(spacing: 14) {
            ItemArtwork(item: item, cornerRadius: 10)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                if style.showsSummaries {
                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(style.summaryLines)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ItemCard: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ItemArtwork(item: item, cornerRadius: 14)
                .aspectRatio(4 / 3, contentMode: .fit)
            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
}

/// Shows an item, and moves the artwork beside the text when its own container is wide.
struct ItemDetailView: View {
    let item: Item
    @State private var isWide = false

    var body: some View {
        ScrollView {
            let layout = isWide
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            layout {
                ItemArtwork(item: item, cornerRadius: 24)
                    .aspectRatio(isWide ? 1 : 16 / 10, contentMode: .fit)
                    .frame(maxWidth: isWide ? 320 : .infinity)
                ItemArticle(item: item)
            }
            .padding()
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height * 1.15 && proxy.size.width > 560
        } action: { isWide = $0 }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ItemArticle: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(.largeTitle.bold())
            Text(item.summary)
                .font(.title3)
                .foregroundStyle(item.color)
            ForEach(item.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Item {
    var previous: Item {
        Item.samples[(id - 1 + Item.samples.count) % Item.samples.count]
    }

    var next: Item {
        Item.samples[(id + 1) % Item.samples.count]
    }
}

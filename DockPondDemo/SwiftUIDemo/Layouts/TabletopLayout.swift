import SwiftUI

/// Half open with a horizontal fold: a viewer on the upper half and controls on the
/// lower half, split exactly at the fold.
struct TabletopLayout: View {
    @Binding var selection: Item?
    @Environment(\.duoContext) private var context
    @State private var progress = 0.35
    @State private var isPlaying = false

    private var item: Item { selection ?? Item.samples[0] }

    var body: some View {
        let topHeight = max(0, context.foldCenterInContent.y - DuoContext.foldGutter / 2)
        VStack(spacing: DuoContext.foldGutter) {
            viewer
                .frame(height: topHeight)
            controls
                .frame(maxHeight: .infinity)
        }
        .background(.black)
        .animation(.smooth, value: item)
    }

    private var viewer: some View {
        ItemArtwork(item: item, cornerRadius: 16)
            .overlay(alignment: .bottomLeading) {
                Text(item.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
                    .padding()
            }
            .padding(.horizontal)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .tint(item.color)
            HStack(spacing: 40) {
                Button("Previous", systemImage: "backward.fill") { selection = item.previous }
                Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                    isPlaying.toggle()
                }
                .font(.largeTitle)
                Button("Next", systemImage: "forward.fill") { selection = item.next }
            }
            .labelStyle(.iconOnly)
            .font(.title)
            .foregroundStyle(.white)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Item.samples) { sample in
                        Button {
                            selection = sample
                        } label: {
                            ItemArtwork(item: sample, cornerRadius: 10)
                                .frame(width: 72, height: 72)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.white, lineWidth: sample == item ? 3 : 0)
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
            .frame(height: 80)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.12), in: .rect(cornerRadius: 20))
        .padding(.horizontal)
        .environment(\.colorScheme, .dark)
    }
}

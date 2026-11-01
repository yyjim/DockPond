import SwiftUI

struct HomeView: View {
    @State private var showsAbout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pick a pond.")
                        .font(.pond(36, weight: .bold))
                    Text("Three toys. Each one runs a real library.")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.label.opacity(0.75))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 22)], spacing: 22) {
                    ForEach(Array(Island.allCases.enumerated()), id: \.element) { index, island in
                        NavigationLink(value: island) {
                            IslandCard(island: island)
                                .bobbing(height: 2, tilt: 0.6, speed: 1.1, offset: Double(index) * 1.7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("island-\(island.rawValue)")
                    }
                }
                Color.clear.frame(height: 130)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color.label)
        .background(Color.foam.ignoresSafeArea())
        .overlay {
            GeometryReader { proxy in
                HomeWater()
                    .frame(height: 120 + proxy.safeAreaInsets.bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: [.bottom, .horizontal])
            }
            .allowsHitTesting(false)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsAbout) { AboutSheet() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("logo")
                .resizable()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            Text("DockPond")
                .font(.pond(26, weight: .bold))
            Spacer()
            Button {
                showsAbout = true
            } label: {
                Image(systemName: "info")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.navy)
                    .frame(width: 44, height: 44)
                    .sticker(.white, radius: 22, shadow: 3)
            }
            .accessibilityLabel("About the pond")
        }
        .padding(.top, 8)
    }
}

private struct IslandCard: View {
    let island: Island

    var body: some View {
        HStack(spacing: 14) {
            Image(island.art)
                .resizable()
                .scaledToFit()
                .padding(4)
                .frame(width: 104, height: 104)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.navy, lineWidth: 3))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(island.library.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(1)
                Text(island.title)
                    .font(.pond(25, weight: .bold))
                Text(island.pitch)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.navy)
            Spacer(minLength: 0)
        }
        .padding(12)
        .sticker(island.fill, radius: 26)
        .rotationEffect(.degrees(island.tilt))
        .contentShape(Rectangle())
    }
}

private struct HomeWater: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                PondWater(amplitude: 10, speed: 1.2, lines: 3)
                RippleRings()
                    .frame(width: 110, height: 28)
                    .offset(x: proxy.size.width * 0.28 - 55, y: 64)
                Image("logo")
                    .resizable()
                    .frame(width: 84, height: 84)
                    .bobbing(height: 5, tilt: 4)
                    .offset(x: proxy.size.width * 0.28 - 42, y: -18)
                    .accessibilityHidden(true)
                Image("duck-paddle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .bobbing(height: 4, tilt: 10, speed: 1.3, offset: 2)
                    .offset(x: proxy.size.width * 0.62, y: 26)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("logo")
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("About the pond")
                .font(.pond(28, weight: .bold))
            Text("Each island uses one DockPond library. The lifeguard float shows on every screen. It combines all three: a FloatingDock with the GaugeDock rows, the appearance switch, and a button that opens the TweakDock screen.")
            Text("Shake the device on any screen to open the Duck Studio tweaks. In Simulator, press Control-Command-Z.")
            Button("Back to the water") { dismiss() }
                .buttonStyle(StickerButtonStyle())
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.label)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.sand.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

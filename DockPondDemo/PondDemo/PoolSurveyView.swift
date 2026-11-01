import GaugeDock
import SwiftUI

struct PoolSurveyView: View {
    let gauge: LayoutGauge

    private var snapshot: LayoutGauge.Snapshot { gauge.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            PondHeader(title: "Pool Survey") {
                BadgeLabel(text: poolName, fill: .float)
                    .accessibilityIdentifier("poolName")
            }
            GeometryReader { proxy in
                let isWide = proxy.size.width > proxy.size.height
                let layout = isWide ? AnyLayout(HStackLayout(spacing: 18)) : AnyLayout(VStackLayout(spacing: 18))
                layout {
                    PoolMap(snapshot: snapshot)
                    FactsCard(snapshot: snapshot)
                        .frame(maxWidth: isWide ? 300 : .infinity)
                }
                .padding(16)
            }
        }
        .foregroundStyle(Color.label)
        .background(Color.sand.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.smooth, value: snapshot)
    }

    private var poolName: String {
        switch snapshot.fold?.posture {
        case .book: return "Twin pools"
        case .tabletop: return "Lounge"
        case .flat: return "Lagoon"
        case .closed, nil: break
        }
        return snapshot.horizontalSizeClass == .regular ? "Olympic" : "Kiddie pool"
    }
}

/// The window drawn to scale as a pool seen from above. The tiled rim is the
/// safe area, and a bridge crosses the fold.
private struct PoolMap: View {
    let snapshot: LayoutGauge.Snapshot

    var body: some View {
        GeometryReader { proxy in
            let window = snapshot.windowSize
            let room = CGSize(width: max(0, proxy.size.width - 52), height: max(0, proxy.size.height - 52))
            let scale = window.width > 0 && window.height > 0 ? min(room.width / window.width, room.height / window.height) : 0
            let size = CGSize(width: window.width * scale, height: window.height * scale)
            let insets = snapshot.safeAreaInsets

            ZStack {
                ZStack(alignment: .topLeading) {
                    Color.pond
                    rim(insets: insets, scale: scale, size: size)
                    lanes(size: size, insets: insets, scale: scale)
                    foldBridge(scale: scale, size: size)
                    badges(insets: insets, scale: scale, size: size)
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.ink, lineWidth: 3))

                Text("← \(Int(window.width)) PT →")
                    .font(.pond(13, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Color.label.opacity(0.75))
                    .offset(y: -size.height / 2 - 14)
                Text("\(Int(window.height)) PT")
                    .font(.pond(13, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Color.label.opacity(0.75))
                    .fixedSize()
                    .rotationEffect(.degrees(90))
                    .offset(x: size.width / 2 + 16)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .sticker(.card, radius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pool map of a window \(Int(snapshot.windowSize.width)) by \(Int(snapshot.windowSize.height)) points")
    }

    private func rim(insets: UIEdgeInsets, scale: CGFloat, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            band(width: size.width, height: insets.top * scale, label: "safe top · \(Int(insets.top))")
            band(width: size.width, height: insets.bottom * scale, label: "bottom · \(Int(insets.bottom))")
                .offset(y: size.height - insets.bottom * scale)
            band(width: insets.left * scale, height: size.height, label: nil)
            band(width: insets.right * scale, height: size.height, label: nil)
                .offset(x: size.width - insets.right * scale)
        }
    }

    private func band(width: CGFloat, height: CGFloat, label: String?) -> some View {
        Color.float
            .frame(width: width, height: height)
            .overlay {
                if let label, height >= 16 {
                    Text(label)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.navy)
                }
            }
    }

    private func lanes(size: CGSize, insets: UIEdgeInsets, scale: CGFloat) -> some View {
        let top = insets.top * scale
        let height = size.height - (insets.top + insets.bottom) * scale
        return ForEach(1..<4, id: \.self) { index in
            Rectangle()
                .fill(Color.foam.opacity(0.5))
                .frame(width: 3, height: max(0, height))
                .offset(x: size.width * CGFloat(index) / 4 - 1.5, y: top)
        }
    }

    @ViewBuilder
    private func foldBridge(scale: CGFloat, size: CGSize) -> some View {
        if let fold = snapshot.fold, let axis = fold.axis, let position = fold.position {
            let point = position * scale
            let isVertical = axis == .vertical
            ZStack {
                Rectangle()
                    .fill(Color.ink)
                    .frame(width: isVertical ? 8 : size.width, height: isVertical ? size.height : 8)
                Image("logo")
                    .resizable()
                    .frame(width: 84, height: 84)
                    .bobbing(height: 3, tilt: 3)
            }
            .position(x: isVertical ? point : size.width / 2, y: isVertical ? size.height / 2 : point)
        } else {
            Image("logo")
                .resizable()
                .frame(width: min(120, size.width * 0.4), height: min(120, size.width * 0.4))
                .bobbing(height: 5, tilt: 4)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }

    private func badges(insets: UIEdgeInsets, scale: CGFloat, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            sizeClassTag("\(name(snapshot.horizontalSizeClass)) width")
                .offset(x: 10 + insets.left * scale, y: insets.top * scale + 10)
            sizeClassTag("\(name(snapshot.verticalSizeClass)) height")
                .frame(width: max(0, size.width - 10 - insets.right * scale), alignment: .trailing)
                .offset(y: size.height - insets.bottom * scale - 38)
        }
    }

    private func sizeClassTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.navy)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.duck, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.navy, lineWidth: 2))
    }

    private func name(_ sizeClass: UIUserInterfaceSizeClass) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "unknown"
        }
    }
}

private struct FactsCard: View {
    let snapshot: LayoutGauge.Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Measured by GaugeDock")
                    .font(.pond(17, weight: .bold))
                    .foregroundStyle(Color.duck)
                Spacer()
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                row("Screen", "\(Int(snapshot.screenSize.width)) × \(Int(snapshot.screenSize.height))")
                row("Window", snapshot.isResized ? "Resized" : "Full screen")
                row("Orientation", snapshot.isLandscape ? "Landscape" : "Portrait")
                row("Scale", "@\(Int(snapshot.displayScale))x")
                row("Hinge", snapshot.hinge.map { "\($0.state.rawValue), \(Int($0.angle.value))°" } ?? "None")
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Color(hex: 0x1C2152), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .fontWeight(.heavy)
                .foregroundStyle(Color.float)
            Text(value)
        }
    }
}

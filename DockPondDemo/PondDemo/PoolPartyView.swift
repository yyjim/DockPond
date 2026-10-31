import FloatingDock
import SwiftUI

struct PartyDuck: Identifiable {
    enum Pose: String, CaseIterable {
        case chill, paddle, dive, sleep
    }

    let id = UUID()
    var position: CGPoint
    var pose: Pose
    var phase: Double
}

@Observable
final class PartyModel {
    var ducks: [PartyDuck] = [
        PartyDuck(position: CGPoint(x: 0.25, y: 0.3), pose: .chill, phase: 0),
        PartyDuck(position: CGPoint(x: 0.68, y: 0.48), pose: .paddle, phase: 1.3),
        PartyDuck(position: CGPoint(x: 0.3, y: 0.66), pose: .sleep, phase: 2.6),
    ]
    var waveHeight = 1.0
    var showsBubbles = true
    var isNightSwim = false
    var duckScale = 1.0
    var cannonballs = 0

    func addDuck(at position: CGPoint? = nil) {
        guard ducks.count < 24 else { ducks.removeFirst(); return addDuck(at: position) }
        let spot = position ?? CGPoint(x: .random(in: 0.12...0.88), y: .random(in: 0.2...0.8))
        ducks.append(PartyDuck(position: spot, pose: PartyDuck.Pose.allCases.randomElement()!, phase: .random(in: 0...6)))
    }
}

struct PoolPartyView: View {
    @State private var model = PartyModel()

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .top) {
            PoolScene(model: model)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                PondHeader(title: "Pool Party", titleColor: .white) {
                    BadgeLabel(text: model.ducks.count == 1 ? "1 duck" : "\(model.ducks.count) ducks")
                }
                Spacer()
                tip
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .floatingDock(
            title: "Pool Toys",
            systemImage: "figure.pool.swim",
            panelStyle: .tabs,
            configuration: FloatingDockConfiguration(id: "pool-toys", initialEdge: .trailing, initialPosition: 0.4, tint: .bill)
        ) {
            DockTool("Toys", systemImage: "bird.fill") {
                ToysPanel(model: model)
            }
            DockTool("Water", systemImage: "water.waves") {
                WaterPanel(model: model)
            }
            DockTool.selector("Duck size", selection: $model.duckScale, options: ["S": 0.75, "M": 1.0, "L": 1.3])
            DockTool.toggle("Night swim", isOn: $model.isNightSwim)
        }
    }

    private var tip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Two floats, one pool")
                .font(.pond(17, weight: .bold))
            Text("Tap the water to drop a duck. Drag a float and let go: it docks to the nearest edge. Pool Toys lives only on this screen. The lifeguard float follows you everywhere.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.navy)
        .frame(maxWidth: 560, alignment: .leading)
        .padding(14)
        .sticker(Color(hex: 0xFFF8E6), radius: 18, shadow: 4)
        .padding(16)
    }
}

private struct PoolScene: View {
    let model: PartyModel
    @State private var hop = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                (model.isNightSwim ? Color(hex: 0x15124A) : Color.pond)
                ripples(in: proxy.size)
                if model.showsBubbles {
                    Bubbles()
                }
                if model.ducks.isEmpty {
                    emptyPond
                }
                ForEach(model.ducks) { duck in
                    Image("duck-\(duck.pose.rawValue)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84 * model.duckScale, height: 84 * model.duckScale)
                        .bobbing(height: 5 * model.waveHeight, tilt: 6 * model.waveHeight, speed: 1.4, offset: duck.phase)
                        .offset(y: hop ? -70 : 0)
                        .position(x: duck.position.x * proxy.size.width, y: duck.position.y * proxy.size.height)
                        .transition(.asymmetric(insertion: .scale(scale: 0.2).combined(with: .offset(y: -120)), removal: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                    model.addDuck(at: CGPoint(x: location.x / proxy.size.width, y: location.y / proxy.size.height))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: model.duckScale)
            .animation(.easeInOut(duration: 0.6), value: model.isNightSwim)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: model.cannonballs)
        .onChange(of: model.cannonballs) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { hop = true }
            Task {
                try? await Task.sleep(for: .milliseconds(260))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { hop = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pool with \(model.ducks.count) ducks")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("pool")
    }

    private var emptyPond: some View {
        VStack(spacing: 12) {
            Image("empty-pond")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .bobbing(height: 4, tilt: 2)
            Text("Empty pool. Tap the water.")
                .font(.pond(18, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func ripples(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    WaveShape(phase: phase * 0.8 + Double(index), amplitude: 6 * model.waveHeight + 2, wavelength: 130, closed: false)
                        .stroke(Color.ripple, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: size.width * 0.45, height: 20)
                        .position(
                            x: size.width * (index.isMultiple(of: 2) ? 0.3 : 0.7),
                            y: size.height * (0.18 + Double(index) * 0.14)
                        )
                }
            }
        }
    }
}

private struct Bubbles: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0..<14 {
                    let seed = Double(index) * 0.618
                    let progress = (t * (0.05 + seed.truncatingRemainder(dividingBy: 0.07)) + seed).truncatingRemainder(dividingBy: 1)
                    let x = size.width * (seed * 7).truncatingRemainder(dividingBy: 1) + sin(t + seed * 9) * 8
                    let y = size.height * (1 - progress)
                    let radius = 4 + (seed * 13).truncatingRemainder(dividingBy: 6)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)), lineWidth: 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ToysPanel: View {
    let model: PartyModel

    var body: some View {
        VStack(spacing: 10) {
            Button("Add a duck") {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { model.addDuck() }
            }
            .buttonStyle(StickerButtonStyle(fill: .duck))
            Button("Cannonball!") { model.cannonballs += 1 }
                .buttonStyle(StickerButtonStyle(fill: .bill))
            Button("Empty the pool") {
                withAnimation { model.ducks.removeAll() }
            }
            .buttonStyle(StickerButtonStyle(fill: .white))
        }
        .padding(.vertical, 4)
        .padding(.trailing, 4)
    }
}

private struct WaterPanel: View {
    @Bindable var model: PartyModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wave height")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Slider(value: $model.waveHeight, in: 0...3)
            }
            Toggle("Bubbles", isOn: $model.showsBubbles)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
        }
    }
}

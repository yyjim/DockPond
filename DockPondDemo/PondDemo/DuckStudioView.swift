import Combine
import SwiftUI
import TweakDock

@MainActor
final class StudioModel: ObservableObject {
    @Published var mood = StudioTweaks.mood
    @Published var size = StudioTweaks.size
    @Published var wobble = StudioTweaks.wobble
    @Published var ducklings = StudioTweaks.ducklings
    @Published var bubbleText = StudioTweaks.bubbleText
    @Published var partyLights = StudioTweaks.partyLights

    init() {
        StudioTweaks.moodTweak.publisher.receive(on: DispatchQueue.main).assign(to: &$mood)
        StudioTweaks.sizeTweak.publisher.receive(on: DispatchQueue.main).assign(to: &$size)
        StudioTweaks.wobbleTweak.publisher.receive(on: DispatchQueue.main).assign(to: &$wobble)
        StudioTweaks.ducklingsTweak.publisher.receive(on: DispatchQueue.main).assign(to: &$ducklings)
        StudioTweaks.bubbleTextTweak.publisher.receive(on: DispatchQueue.main).assign(to: &$bubbleText)
        StudioTweaks.partyLightsTweak.publisher.receive(on: DispatchQueue.main).assign(to: &$partyLights)
    }
}

struct DuckStudioView: View {
    let openTweaks: () -> Void
    @StateObject private var model = StudioModel()
    @State private var quacks = 0
    @State private var isHopping = false

    var body: some View {
        VStack(spacing: 14) {
            PondHeader(title: "Duck Studio", titleColor: .white) {
                HStack(spacing: 6) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                    Text("Shake")
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .sticker(.bill, radius: 16, shadow: 3)
            }
            Stage(model: model, quacks: quacks, isHopping: isHopping)
            CodeStrip(model: model)
                .padding(.horizontal, 16)
            HStack(spacing: 12) {
                Button("Open tweaks", action: openTweaks)
                    .buttonStyle(StickerButtonStyle(fill: .white))
                    .accessibilityIdentifier("openTweaks")
                Button("Quack now") { StudioTweaks.quackTweak() }
                    .buttonStyle(StickerButtonStyle(fill: .duck))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: 600)
        }
        .background(Color.deep.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .medium), trigger: quacks)
        .onReceive(NotificationCenter.default.publisher(for: .studioQuack)) { _ in
            quacks += 1
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { isHopping = true }
            Task {
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { isHopping = false }
            }
        }
    }
}

private struct Stage: View {
    @ObservedObject var model: StudioModel
    let quacks: Int
    let isHopping: Bool

    var body: some View {
        GeometryReader { proxy in
            let duckSide = min(proxy.size.width * 0.55, proxy.size.height * 0.7) * model.size
            ZStack(alignment: .bottom) {
                if model.partyLights {
                    PartyLights()
                        .transition(.opacity)
                }
                platform(width: min(proxy.size.width - 40, 420))
                ducklingRow(width: min(proxy.size.width - 32, 460))
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Image("studio-\(model.mood.rawValue)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: duckSide, height: duckSide)
                        .rotationEffect(.degrees(sin(t * (2 + model.wobble)) * 4 * model.wobble), anchor: .bottom)
                }
                .offset(y: isHopping ? -60 : -30)
                .accessibilityLabel("The studio duck, \(model.mood.rawValue)")
                .accessibilityIdentifier("studioDuck")
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .topTrailing) {
                bubble
                    .padding(.trailing, 22)
                    .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: model.size)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: model.ducklings)
        .animation(.easeInOut, value: model.partyLights)
    }

    private var bubble: some View {
        Text(quacks > 0 ? "QUACK ×\(quacks)" : model.bubbleText)
            .font(.pond(22, weight: .bold))
            .foregroundStyle(Color.navy)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .frame(maxWidth: 170)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 4, bottomTrailingRadius: 20, topTrailingRadius: 20)
                    .fill(Color.ink)
                    .offset(x: 4, y: 4)
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 4, bottomTrailingRadius: 20, topTrailingRadius: 20)
                    .fill(.white)
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 4, bottomTrailingRadius: 20, topTrailingRadius: 20)
                    .strokeBorder(Color.ink, lineWidth: 3)
            }
            .contentTransition(.numericText())
            .animation(.snappy, value: quacks)
            .accessibilityIdentifier("bubble")
    }

    private func platform(width: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.pond)
                .overlay(Ellipse().strokeBorder(Color.ink, lineWidth: 3))
                .frame(width: width, height: 70)
            Ellipse()
                .strokeBorder(Color.float, lineWidth: 3)
                .frame(width: width * 0.72, height: 42)
                .offset(y: -6)
        }
        .padding(.bottom, 8)
    }

    private func ducklingRow(width: CGFloat) -> some View {
        HStack(alignment: .bottom) {
            ForEach(0..<model.ducklings, id: \.self) { index in
                Image("duck-paddle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .scaleEffect(x: index.isMultiple(of: 2) ? 1 : -1)
                    .bobbing(height: 3, tilt: 6, speed: 3, offset: Double(index))
                    .transition(.scale.combined(with: .opacity))
                if index != model.ducklings - 1 { Spacer(minLength: 0) }
            }
        }
        .frame(width: width)
        .padding(.bottom, 20)
        .accessibilityHidden(true)
    }
}

private struct PartyLights: View {
    private let colors: [Color] = [.duck, .bill, .float, .white]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(colors.indices, id: \.self) { index in
                    Beam()
                        .fill(colors[index].opacity(0.35))
                        .rotationEffect(.degrees(sin(t * 1.5 + Double(index) * 1.6) * 28), anchor: .top)
                        .offset(x: CGFloat(index - 2) * 70 + 35)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private nonisolated struct Beam: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + 70, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - 70, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CodeStrip: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            line("Mood", ".\(model.mood.rawValue)")
            line("Ducklings", "\(model.ducklings)")
            line("Wobble", model.wobble.formatted(.number.precision(.fractionLength(1))))
        }
        .font(.system(size: 12.5, design: .monospaced))
        .foregroundStyle(Color(hex: 0xEFEBFF))
        .frame(maxWidth: 600, alignment: .leading)
        .padding(12)
        .background(Color(hex: 0x1C2152), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func line(_ name: String, _ value: String) -> Text {
        Text("@Tweak").foregroundStyle(Color.float)
            + Text("(name: \"\(name)\") = ")
            + Text(value).foregroundStyle(Color.duck).bold()
    }
}

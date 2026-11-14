import SwiftUI

nonisolated struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var wavelength: CGFloat = 180
    var closed = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.minY + amplitude
        path.move(to: CGPoint(x: rect.minX, y: midY + sin(phase) * amplitude))
        for x in stride(from: rect.minX, through: rect.maxX + 4, by: 4) {
            let angle = phase + Double(x / wavelength) * 2 * .pi
            path.addLine(to: CGPoint(x: x, y: midY + sin(angle) * amplitude))
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// Pond water: a filled wave on top and drifting ripple lines below it.
struct PondWater: View {
    var amplitude: CGFloat = 10
    var speed: Double = 1
    var lines = 4

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * speed
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    WaveShape(phase: phase, amplitude: amplitude)
                        .fill(Color.pond)
                    WaveShape(phase: phase, amplitude: amplitude)
                        .stroke(Color.ink, lineWidth: 3)
                    ForEach(0..<lines, id: \.self) { index in
                        let y = amplitude * 2 + CGFloat(index + 1) * proxy.size.height / CGFloat(lines + 1)
                        WaveShape(phase: phase * 0.7 + Double(index), amplitude: amplitude * 0.5, wavelength: 140, closed: false)
                            .stroke(Color.ripple, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: proxy.size.width * 0.5, height: amplitude + 4)
                            .offset(x: index.isMultiple(of: 2) ? -proxy.size.width * 0.18 : proxy.size.width * 0.22, y: y)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct Bobbing: ViewModifier {
    var height: CGFloat = 6
    var tilt: Double = 3
    var speed: Double = 1.6
    var offset: Double = 0
    var isPaused = false

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: isPaused)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed + offset
            content
                .offset(y: sin(t) * height)
                .rotationEffect(.degrees(sin(t * 0.8) * tilt))
        }
    }
}

extension View {
    func bobbing(height: CGFloat = 6, tilt: Double = 3, speed: Double = 1.6, offset: Double = 0, isPaused: Bool = false) -> some View {
        modifier(Bobbing(height: height, tilt: tilt, speed: speed, offset: offset, isPaused: isPaused))
    }
}

struct RippleRings: View {
    var color: Color = .foam

    var body: some View {
        ZStack {
            Ellipse().stroke(color.opacity(0.6), lineWidth: 2.5)
            Ellipse().stroke(color.opacity(0.9), lineWidth: 2.5).scaleEffect(0.6)
        }
        .accessibilityHidden(true)
    }
}

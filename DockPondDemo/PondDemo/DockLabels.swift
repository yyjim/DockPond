import FloatingDock
import SwiftUI

/// The Pool Toys button: a rubber duck in a round sticker with a strip of pond
/// water. It faces away from its edge, paddles when you lift it out of the water,
/// dives when the panel opens, and naps when the button fades.
struct DuckFloatLabel: View {
    let state: FloatingDockButtonState

    var body: some View {
        ZStack {
            disc
            duck
        }
        .frame(width: 76, height: 76)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: state)
    }

    private var art: String {
        if state.isExpanded { return "duck-dive" }
        if state.isDragging { return "duck-paddle" }
        if state.isIdle { return "duck-sleep" }
        return "duck-chill"
    }

    // The art faces right, so a duck on the trailing edge turns to face the screen.
    private var facesLeft: Bool { state.edge == .trailing }

    private var disc: some View {
        TimelineView(.animation) { timeline in
            Circle()
                .fill(Color.card)
                .overlay(alignment: .bottom) {
                    WaveShape(phase: timeline.date.timeIntervalSinceReferenceDate * 2, amplitude: 3, wavelength: 40)
                        .fill(Color.ripple)
                        .frame(height: 24)
                }
                .clipShape(Circle())
        }
        .overlay(Circle().strokeBorder(Color.ink, lineWidth: 3))
        .background(Circle().fill(Color.ink).offset(x: 3, y: 3))
        .frame(width: 62, height: 62)
        .scaleEffect(state.isDragging ? 0.9 : 1)
    }

    private var duck: some View {
        StickerArt(name: art, isMirrored: facesLeft)
            .frame(width: 50, height: 50)
            // The dock fades the whole button, and faded yellow over the purple pond looks brown.
            .saturation(state.isIdle ? 0 : 1)
            .bobbing(height: 2, tilt: 4, speed: 1.6)
            .scaleEffect(state.isDragging ? 1.2 : 1)
            .offset(y: state.isDragging ? -16 : -2)
    }
}

/// The Lifeguard button: the lifebuoy floats, and lifts out of the water while you
/// drag it.
struct LifebuoyLabel: View {
    let state: FloatingDockButtonState

    var body: some View {
        StickerArt(name: "lifebuoy")
            .frame(width: 56, height: 56)
            .bobbing(height: 3, tilt: 5, speed: 1.3)
            .scaleEffect(state.isDragging ? 1.15 : 1)
            .offset(y: state.isDragging ? -6 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: state.isDragging)
    }
}

/// Asset art with the hard ink shadow of the sticker look.
private struct StickerArt: View {
    let name: String
    var isMirrored = false

    var body: some View {
        art(.original)
            .background {
                art(.template)
                    .foregroundStyle(Color.ink)
                    .offset(x: 3, y: 3)
            }
    }

    private func art(_ mode: Image.TemplateRenderingMode) -> some View {
        Image(name)
            .resizable()
            .renderingMode(mode)
            .scaledToFit()
            .scaleEffect(x: isMirrored ? -1 : 1)
    }
}

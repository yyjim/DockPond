import FloatingDock
import SwiftUI

/// The Pool Toys button: a rubber duck that floats on a puddle. It faces away
/// from its edge, paddles when you lift it out of the water, dives when the panel
/// opens, and naps when the button fades.
struct DuckFloatLabel: View {
    let state: FloatingDockButtonState

    var body: some View {
        ZStack {
            puddle
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

    private var puddle: some View {
        ZStack {
            Ellipse()
                .fill(Color.float)
            Ellipse()
                .strokeBorder(Color.ink, lineWidth: 3)
            RippleRings(color: .foam)
                .padding(5)
        }
        .frame(width: 66, height: 22)
        .offset(y: 24)
        .scaleEffect(state.isDragging ? 0.4 : 1, anchor: .bottom)
        .opacity(state.isDragging ? 0 : 1)
    }

    private var duck: some View {
        StickerArt(name: art, isMirrored: facesLeft)
            .frame(width: 58, height: 58)
            .bobbing(height: 4, tilt: 4, speed: 1.6)
            .scaleEffect(state.isDragging ? 1.18 : 1)
            .offset(y: state.isDragging ? -6 : 0)
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

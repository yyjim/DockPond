import SwiftUI
import UIKit

extension Color {
    static let duck = Color(hex: 0xFFC93C)
    static let bill = Color(hex: 0xFF8A1F)
    static let float = Color(hex: 0xB7A9FF)
    static let navy = Color(hex: 0x1C2152)

    static let sand = Color(light: 0xFFF8E6, dark: 0x15183A)
    static let foam = Color(light: 0xEFEBFF, dark: 0x1E2150)
    static let card = Color(light: 0xFFFFFF, dark: 0x2A2E66)
    static let ink = Color(light: 0x1C2152, dark: 0x070918)
    static let label = Color(light: 0x1C2152, dark: 0xFFF8E6)
    static let pond = Color(light: 0x6F5CE6, dark: 0x3E3399)
    static let deep = Color(light: 0x3E3399, dark: 0x221C66)
    static let ripple = Color(light: 0xB7A9FF, dark: 0x6F5CE6)

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    static func pond(_ size: CGFloat, weight: Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// The sticker look of the duck art: a thick ink outline and a hard offset shadow.
struct Sticker: ViewModifier {
    var fill: Color
    var radius: CGFloat
    var shadow: CGFloat

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.ink)
                .offset(x: shadow, y: shadow)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.ink, lineWidth: 3)
        }
    }
}

extension View {
    func sticker(_ fill: Color = .card, radius: CGFloat = 22, shadow: CGFloat = 5) -> some View {
        modifier(Sticker(fill: fill, radius: radius, shadow: shadow))
    }
}

struct StickerButtonStyle: ButtonStyle {
    var fill: Color = .duck

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pond(17))
            .foregroundStyle(Color.navy)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 12)
            .sticker(fill, radius: 14, shadow: configuration.isPressed ? 0 : 3)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

struct CircleBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color.navy)
                .frame(width: 44, height: 44)
                .sticker(.white, radius: 22, shadow: 3)
        }
        .accessibilityLabel("Back to the pond")
    }
}

/// A screen title row with a round back button and an optional badge.
struct PondHeader<Badge: View>: View {
    let title: String
    var titleColor: Color = .label
    @ViewBuilder var badge: Badge

    var body: some View {
        HStack(spacing: 12) {
            CircleBackButton()
            Text(title)
                .font(.pond(28, weight: .bold))
                .foregroundStyle(titleColor)
            Spacer(minLength: 8)
            badge
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct BadgeLabel: View {
    let text: String
    var fill: Color = .duck

    var body: some View {
        Text(text)
            .font(.pond(15, weight: .bold))
            .foregroundStyle(Color.navy)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .sticker(fill, radius: 16, shadow: 3)
            .contentTransition(.numericText())
    }
}

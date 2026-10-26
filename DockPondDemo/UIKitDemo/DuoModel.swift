import UIKit

struct HingeReading: Equatable {
    var state: HingeState
    var angleDegrees: Int?

    static let unavailable = HingeReading(state: .unavailable, angleDegrees: nil)
}

struct HingeEvent {
    let date: Date
    let reading: HingeReading
}

final class DuoSettings {
    var stateOverride = UserDefaults.standard.string(forKey: "HingeStateOverride").flatMap(HingeState.init(rawValue:))
    var axisOverride = UserDefaults.standard.string(forKey: "FoldAxisOverride").flatMap(FoldAxis.init(rawValue:))
    var showsFoldLine = true
    private(set) var events: [HingeEvent] = []
    var onChange: (() -> Void)?

    func record(_ reading: HingeReading) {
        guard events.first?.reading.state != reading.state else { return }
        events.insert(HingeEvent(date: .now, reading: reading), at: 0)
        if events.count > 30 {
            events.removeLast()
        }
        NotificationCenter.default.post(name: Self.historyDidChange, object: self)
    }

    static let historyDidChange = Notification.Name("DuoSettingsHistoryDidChange")

    func notifyChange() {
        onChange?()
    }
}

/// Everything a screen needs to pick its layout. The fold position comes from the
/// window shape, because iOS reports the hinge state and angle but not where the
/// fold is. On the Duo inner display the fold crosses the longer edge.
struct DuoState: Equatable {
    var hasHinge: Bool
    var reading: HingeReading
    var windowSize: CGSize
    var horizontalSizeClass: UIUserInterfaceSizeClass
    var axisOverride: FoldAxis?

    var isLandscape: Bool { windowSize.width > windowSize.height }

    var foldAxis: FoldAxis { axisOverride ?? (isLandscape ? .vertical : .horizontal) }

    var hasFold: Bool { reading.state == .partiallyOpen || reading.state == .fullyOpen }

    var posture: Posture {
        Posture(state: reading.state, foldAxis: foldAxis, isRegularWidth: horizontalSizeClass == .regular)
    }
}

struct Swatch: Hashable {
    let name: String
    let color: UIColor
    let summary: String

    var article: String {
        [
            "\(name) is one of the colors in this sample. \(summary)",
            "Fold the device, turn it, or open it flat. The same color stays selected while the layout changes around it.",
            "Half open with a vertical fold, the app shows a two-page spread. With a horizontal fold, it shows a viewer above the controls. Nothing is placed on the fold.",
        ].joined(separator: "\n\n")
    }

    var next: Swatch { Swatch.all[(index + 1) % Swatch.all.count] }
    var previous: Swatch { Swatch.all[(index - 1 + Swatch.all.count) % Swatch.all.count] }
    var index: Int { Swatch.all.firstIndex(of: self) ?? 0 }

    static let all: [Swatch] = [
        Swatch(name: "Red", color: .systemRed, summary: "Strong and warm, it pulls the eye first."),
        Swatch(name: "Orange", color: .systemOrange, summary: "Bright and friendly, between red and yellow."),
        Swatch(name: "Yellow", color: .systemYellow, summary: "The lightest of the warm colors."),
        Swatch(name: "Green", color: .systemGreen, summary: "Calm and natural, often used for success."),
        Swatch(name: "Mint", color: .systemMint, summary: "A light green with a touch of blue."),
        Swatch(name: "Teal", color: .systemTeal, summary: "Between green and blue, cool and clear."),
        Swatch(name: "Cyan", color: .systemCyan, summary: "A bright, light blue."),
        Swatch(name: "Blue", color: .systemBlue, summary: "The system tint color on iOS."),
        Swatch(name: "Indigo", color: .systemIndigo, summary: "A deep blue near violet."),
        Swatch(name: "Purple", color: .systemPurple, summary: "Rich and cool, between blue and red."),
        Swatch(name: "Pink", color: .systemPink, summary: "A light, warm red."),
        Swatch(name: "Brown", color: .systemBrown, summary: "Dark orange with low saturation."),
    ]
}

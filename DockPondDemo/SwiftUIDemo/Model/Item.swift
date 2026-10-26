import SwiftUI

struct Item: Identifiable, Hashable {
    let id: Int
    let title: String
    let symbol: String
    let hue: Double
    let summary: String

    var color: Color { Color(hue: hue, saturation: 0.7, brightness: 0.85) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.75, brightness: 0.95),
                Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.6),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var paragraphs: [String] {
        [
            "\(title) is one of the places in this sample gallery. \(summary)",
            "Fold the device, turn it, or open it flat. The same item stays selected while the layout changes around it, so you can see how each posture presents the same content.",
            "On the outer display the gallery is a single column. Fully open, it becomes a split view. Half open, the content moves away from the fold: a book spread with a vertical fold, or a viewer above controls with a horizontal fold.",
            "Use the diagnostics panel to compare the live hinge state with the window size, the size classes, and the posture the app derived from them.",
        ]
    }

    static let samples: [Item] = [
        Item(id: 0, title: "Aurora", symbol: "sparkles", hue: 0.48, summary: "Green ribbons of light move across a polar sky."),
        Item(id: 1, title: "Canyon", symbol: "mountain.2.fill", hue: 0.05, summary: "Red rock walls drop a thousand meters to a river."),
        Item(id: 2, title: "Lagoon", symbol: "water.waves", hue: 0.55, summary: "Clear, shallow water sits behind a coral reef."),
        Item(id: 3, title: "Meadow", symbol: "leaf.fill", hue: 0.3, summary: "Wild flowers cover a high valley in early summer."),
        Item(id: 4, title: "Dunes", symbol: "sun.max.fill", hue: 0.1, summary: "Wind shapes the sand into long, curved ridges."),
        Item(id: 5, title: "Glacier", symbol: "snowflake", hue: 0.58, summary: "Blue ice moves slowly down from the peaks."),
        Item(id: 6, title: "Volcano", symbol: "flame.fill", hue: 0.0, summary: "A young cone still releases steam from its crater."),
        Item(id: 7, title: "Rainforest", symbol: "tree.fill", hue: 0.36, summary: "Rain falls on most days under a dense canopy."),
        Item(id: 8, title: "Nebula", symbol: "moon.stars.fill", hue: 0.75, summary: "Gas and dust glow far from any city light."),
        Item(id: 9, title: "Harbor", symbol: "ferry.fill", hue: 0.62, summary: "Boats come and go between old stone piers."),
        Item(id: 10, title: "Orchard", symbol: "basket.fill", hue: 0.95, summary: "Rows of fruit trees fill a quiet hillside."),
        Item(id: 11, title: "Tundra", symbol: "wind", hue: 0.15, summary: "Low plants survive a short summer and long winter."),
    ]
}

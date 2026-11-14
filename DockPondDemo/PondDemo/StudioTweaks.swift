import Foundation
import TweakDock

extension Notification.Name {
    static let studioQuack = Notification.Name("studioQuack")
}

@Tweaks
enum StudioTweaks {
    enum Mood: String, CaseIterable, TweakValue { case chill, smug, party, sleepy }

    @Tweak(collection: "Duck Studio", group: "Duck", name: "Mood", defaultValue: Mood.chill)
    static var mood: Mood

    @Tweak(collection: "Duck Studio", group: "Duck", name: "Size", min: 0.6, max: 1.4, defaultValue: 1.0)
    static var size: Double

    @Tweak(collection: "Duck Studio", group: "Duck", name: "Wobble", min: 0, max: 3, defaultValue: 1.0)
    static var wobble: Double

    @Tweak(collection: "Duck Studio", group: "Family", name: "Ducklings", min: 0, max: 5, defaultValue: 2)
    static var ducklings: Int

    @Tweak(collection: "Duck Studio", group: "Speech", name: "Bubble Text", defaultValue: "sup.")
    static var bubbleText: String

    @Tweak(collection: "Duck Studio", group: "Stage", name: "Party Lights", defaultValue: false)
    static var partyLights: Bool

    @Tweak(collection: "Duck Studio", group: "Speech", name: "Quack Now")
    static func quack() {
        NotificationCenter.default.post(name: .studioQuack, object: nil)
    }
}

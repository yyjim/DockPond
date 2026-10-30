import Foundation
import TweakDock

extension Notification.Name {
    static let demoCacheCleared = Notification.Name("demoCacheCleared")
}

@Tweaks
enum DemoTweaks {
    enum Accent: String, CaseIterable, TweakValue { case blue, orange, purple, green }

    @Tweak(collection: "Card", group: "Text", name: "Title", defaultValue: "Hello, TweakDock")
    static var title: String

    @Tweak(collection: "Card", group: "Text", name: "Font Size", min: 12, max: 40, defaultValue: 20)
    static var fontSize: CGFloat

    @Tweak(collection: "Card", group: "Style", name: "Accent", defaultValue: Accent.blue)
    static var accent: Accent

    @Tweak(collection: "Card", group: "Style", name: "Corner Radius", min: 0, max: 40, defaultValue: 16)
    static var cornerRadius: CGFloat

    @Tweak(collection: "Card", group: "Style", name: "Shows Shadow", defaultValue: true)
    static var showsShadow: Bool

    @Tweak(collection: "Card", group: "Badge", name: "Badge Count", min: 0, max: 9, defaultValue: 3)
    static var badgeCount: Int

    @Tweak(collection: "App", group: "Appearance", name: "Dark Mode", defaultValue: false)
    static var isDarkMode: Bool

    @Tweak(collection: "App", group: "Network", name: "Environment", options: ["production", "staging", "local"], defaultValue: "production")
    static var environment: String

    @Tweak(collection: "App", group: "Network", name: "Max Retries", defaultValue: 3)
    static var maxRetries: Int

    @Tweak(collection: "App", group: "Network", name: "Timeout", defaultValue: 10.0)
    static var timeout: Double

    @Tweak(collection: "App", group: "Debug", name: "Clear Cache")
    static func clearCache() {
        NotificationCenter.default.post(name: .demoCacheCleared, object: nil)
    }
}

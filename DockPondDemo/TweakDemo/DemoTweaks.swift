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

    enum ABC: String, CaseIterable, TweakValue { case A, B, C }
    enum AB: String, CaseIterable, TweakValue { case A, B }

    @Tweak(collection: "Experiments", group: "Remote", name: "Paywall Layout", defaultValue: ABC.A, sourceKey: "exp_paywall_layout")
    static var paywallLayout: ABC

    @Tweak(collection: "Experiments", group: "Remote", name: "Onboarding", defaultValue: AB.A, sourceKey: "exp_onboarding")
    static var onboarding: AB

    @Tweak(collection: "Experiments", group: "Remote", name: "Share Sheet", defaultValue: AB.A, sourceKey: "exp_share_sheet")
    static var shareSheet: AB

    @Tweak(collection: "Experiments", group: "Remote", name: "iPad Sidebar", defaultValue: AB.A, sourceKey: "exp_ipad_sidebar")
    static var iPadSidebar: AB

    @Tweak(collection: "Experiments", group: "Remote", name: "Upload Limit", min: 1, max: 20, defaultValue: 5, sourceKey: "upload_limit")
    static var uploadLimit: Int

    @Tweak(collection: "Experiments", group: "Remote", name: "Fetch Remote Config")
    static func fetchRemoteConfig() {
        DemoSources.fetchRemoteConfig()
    }

    @Tweak(collection: "Experiments", group: "Remote", name: "Clear Remote Config")
    static func clearRemoteConfig() {
        DemoSources.clearRemoteConfig()
    }

    @Tweak(collection: "Experiments", group: "Local Split", name: "Card Style", defaultValue: AB.A, sourceKey: "lab_card_style")
    static var cardStyle: AB

    @Tweak(collection: "Experiments", group: "Local Split", name: "New Badge", defaultValue: false, sourceKey: "rollout_new_badge")
    static var showsNewBadge: Bool

    @Tweak(collection: "Experiments", group: "Local Split", name: "Reassign Buckets")
    static func reassignBuckets() {
        DemoSources.localSplit.reassignAll()
    }
}

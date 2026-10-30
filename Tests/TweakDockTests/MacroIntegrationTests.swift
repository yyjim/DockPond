import CoreGraphics
import Foundation
import Testing
import TweakDock

private extension TweakStore {
    static let integration = TweakStore(
        fileURL: FileManager.default.temporaryDirectory.appending(components: "TweakDockTests", "\(UUID().uuidString).json")
    )
}

@Tweaks(store: .integration)
private enum SampleTweaks {
    enum Size: String, CaseIterable, TweakValue { case small, large }

    @Tweak(collection: "UI", group: "Theme", name: "Integration Dark Mode", defaultValue: true)
    static var isDarkMode: Bool

    @Tweak(collection: "UI", group: "Font", name: "Integration Font Size", min: 10, max: 40, defaultValue: 14)
    static var fontSize: CGFloat

    @Tweak(collection: "UI", group: "Appearance", name: "Integration Size", defaultValue: Size.small)
    static var size: Size

    @MainActor static var cacheClearCount = 0

    @Tweak(collection: "Debug", group: "Session", name: "Integration Clear Cache")
    @MainActor static func clearCache() {
        cacheClearCount += 1
    }
}

@Suite(.serialized) struct MacroIntegrationTests {
    @Test func listsTweaksInDeclarationOrder() {
        #expect(SampleTweaks.allTweaks.map(\.name) == [
            "Integration Dark Mode", "Integration Font Size", "Integration Size", "Integration Clear Cache",
        ])
    }

    @Test func usesTheGivenStore() {
        defer { SampleTweaks.isDarkModeTweak.reset() }
        SampleTweaks.isDarkMode = false
        let reloaded = Tweak(
            collection: "UI", group: "Theme", name: "Integration Dark Mode", defaultValue: true,
            store: TweakStore(fileURL: TweakStore.integration.fileURL)
        )
        #expect(reloaded.value == false)
        #expect(Tweak(collection: "UI", group: "Theme", name: "Integration Dark Mode", defaultValue: true).value == true)
    }

    @Test func readsAndWritesThroughTheStore() {
        defer { SampleTweaks.fontSizeTweak.reset() }
        #expect(SampleTweaks.fontSize == 14)
        SampleTweaks.fontSize = 30
        #expect(SampleTweaks.fontSize == 30)
        #expect(SampleTweaks.fontSizeTweak.defaultValue == 14)
    }

    @Test func supportsEnumTweaks() {
        defer { SampleTweaks.sizeTweak.reset() }
        SampleTweaks.size = .large
        #expect(SampleTweaks.size == .large)
    }

    @Test @MainActor func runsActionTweaks() {
        SampleTweaks.clearCacheTweak()
        #expect(SampleTweaks.cacheClearCount == 1)
    }
}

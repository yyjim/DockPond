import Combine
import Foundation
import Testing
@testable import TweakDock
#if canImport(UIKit)
import UIKit
#endif

@Suite struct TweakSourceTests {
    enum Variant: String, CaseIterable, TweakValue { case A, B, C }

    let store: TweakStore
    let remote = InMemoryTweakSource(name: "Remote")

    init() {
        store = TweakStore(fileURL: FileManager.default.temporaryDirectory
            .appending(components: "TweakDockTests", "\(UUID().uuidString).json"))
        store.source = remote
    }

    private func experiment(_ key: String = "exp_paywall") -> Tweak<Variant> {
        Tweak(collection: "C", group: "G", name: key, defaultValue: Variant.A, sourceKey: key, store: store)
    }

    @Test func usesValidSourceValue() {
        remote.setValue(.string("B"), forKey: "exp_paywall")
        let tweak = experiment()
        #expect(tweak.value == .B)
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func usesDefaultWhenSourceHasNoValue() {
        let tweak = experiment()
        #expect(tweak.value == .A)
        #expect(tweak.currentValue == .default(.A))
    }

    @Test func usesDefaultWhenStoreHasNoSource() {
        store.source = nil
        #expect(experiment().currentValue == .default(.A))
    }

    @Test func usesDefaultForUnknownVariant() {
        remote.setValue(.string("Z"), forKey: "exp_paywall")
        #expect(experiment().currentValue == .default(.A))
    }

    @Test func usesDefaultForValueOutsideRangeOrOptions() {
        remote.replaceValues(["retries": .string("99"), "theme": .string("blue"), "flag": .string("maybe")])
        let retries = Tweak(collection: "C", group: "G", name: "Retries", min: 0, max: 5, defaultValue: 3, sourceKey: "retries", store: store)
        let theme = Tweak(collection: "C", group: "G", name: "Theme", options: ["light", "dark"], defaultValue: "light", sourceKey: "theme", store: store)
        let flag = Tweak(collection: "C", group: "G", name: "Flag", defaultValue: false, sourceKey: "flag", store: store)
        #expect(retries.currentValue == .default(3))
        #expect(theme.currentValue == .default("light"))
        #expect(flag.currentValue == .default(false))

        remote.replaceValues(["retries": .string("4"), "theme": .string("dark"), "flag": .string("true")])
        #expect(retries.value == 4)
        #expect(theme.value == "dark")
        #expect(flag.value == true)
    }

    @Test func ignoresSourceForTweakWithoutSourceKey() {
        remote.setValue(.int(9), forKey: "Count")
        let tweak = Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store)
        #expect(tweak.currentValue == .default(1))
    }

    @Test func overrideHidesSourceValueUntilReset() {
        remote.setValue(.string("B"), forKey: "exp_paywall")
        let tweak = experiment()
        tweak.value = .A
        #expect(tweak.currentValue == .override(.A))
        #expect(store.reading(for: tweak) == TweakReading(current: .override(.A), source: .init(name: "Remote", value: .B)))
        tweak.reset()
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func writeOfShownValueMakesNoOverride() {
        remote.setValue(.string("B"), forKey: "exp_paywall")
        let tweak = experiment()
        tweak.value = .B
        remote.setValue(.string("C"), forKey: "exp_paywall")
        #expect(tweak.currentValue == .source("Remote", .C))
    }

    @Test func combinedSourceSkipsValueThatIsNotValid() {
        let launch = LaunchArgumentTweakSource(arguments: ["app", "-tweak.exp_paywall", "Z"])
        store.source = CombinedTweakSource([launch, remote])
        remote.setValue(.string("B"), forKey: "exp_paywall")
        #expect(experiment().currentValue == .source("Remote", .B))
    }

    @Test func disabledStoreIgnoresOverridesButKeepsSource() {
        remote.setValue(.string("B"), forKey: "exp_paywall")
        let tweak = experiment()
        tweak.value = .C
        store.isEnabled = false
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func publishesSourceChanges() {
        let tweak = experiment()
        var received: [TweakCurrentValue<Variant>] = []
        let subscription = tweak.currentValuePublisher.sink { received.append($0) }

        remote.setValue(.string("B"), forKey: "exp_paywall")
        remote.setValue(.string("Z"), forKey: "exp_paywall")
        store.source = InMemoryTweakSource(name: "Other", values: ["exp_paywall": .string("B")])

        #expect(received == [.default(.A), .source("Remote", .B), .default(.A), .source("Other", .B)])
        subscription.cancel()
    }

    @Test func combinedSourceUsesFirstValueAndItsName() {
        let launch = LaunchArgumentTweakSource(arguments: ["app", "-tweak.exp_paywall", "C"])
        store.source = CombinedTweakSource([launch, remote])
        remote.replaceValues(["exp_paywall": .string("B"), "exp_other": .string("B")])

        #expect(experiment().currentValue == .source("Launch Argument", .C))
        #expect(experiment("exp_other").currentValue == .source("Remote", .B))
    }

    @Test func parsesLaunchArgumentsByKind() {
        let source = LaunchArgumentTweakSource(arguments: [
            "app", "-tweak.flag", "YES", "-tweak.count", "7", "-tweak.bad", "x", "-tweak.empty", "-tweak.last", "L",
        ])
        #expect(source.primitive(forKey: "flag", as: .bool) == .bool(true))
        #expect(source.primitive(forKey: "count", as: .int) == .int(7))
        #expect(source.primitive(forKey: "count", as: .double) == .double(7))
        #expect(source.primitive(forKey: "bad", as: .int) == nil)
        #expect(source.primitive(forKey: "missing", as: .string) == nil)
        #expect(source.primitive(forKey: "empty", as: .string) == nil)
        #expect(source.primitive(forKey: "last", as: .string) == .string("L"))
    }

    @Test func localSplitKeepsAssignmentAndGrowsRollout() throws {
        let suite = "TweakDockTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(0.3, forKey: "TweakDock.split.rollout")
        defaults.set(0.6, forKey: "TweakDock.split.exp")
        let small = LocalSplitTweakSource(splits: ["rollout": .rollout(0.2), "exp": .variants(["A": 1, "B": 1])], defaults: defaults)
        let large = LocalSplitTweakSource(splits: ["rollout": .rollout(0.5)], defaults: defaults)

        #expect(small.primitive(forKey: "rollout", as: .bool) == .bool(false))
        #expect(large.primitive(forKey: "rollout", as: .bool) == .bool(true))
        #expect(small.primitive(forKey: "exp", as: .string) == .string("B"))
        #expect(small.primitive(forKey: "other", as: .string) == nil)

        defaults.set(0.9, forKey: "TweakDock.split.limit")
        let numbers = LocalSplitTweakSource(splits: ["limit": .variants(["3": 1, "5": 1])], defaults: defaults)
        #expect(numbers.primitive(forKey: "limit", as: .int) == .int(5))
    }

    @Test func localSplitAssignsOnFirstReadAndKeepsIt() throws {
        let suite = "TweakDockTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let source = LocalSplitTweakSource(splits: ["exp": .variants(["A": 1, "B": 1, "C": 1])], defaults: defaults)
        let first = source.primitive(forKey: "exp", as: .string)
        #expect(defaults.object(forKey: "TweakDock.split.exp") is Double)
        #expect((0 ..< 20).allSatisfy { _ in source.primitive(forKey: "exp", as: .string) == first })
    }

    #if canImport(UIKit)
    @Test func deviceSourceGivesNoValueOnOtherDevices() {
        remote.replaceValues(["exp_paywall": .string("B"), "exp_other": .string("B")])
        let padOnly: [String: Set<UIUserInterfaceIdiom>] = ["exp_paywall": [.pad]]

        store.source = DeviceTweakSource(remote, devices: padOnly, idiom: .phone)
        #expect(experiment().currentValue == .default(.A))
        #expect(experiment("exp_other").currentValue == .source("Remote", .B))

        store.source = DeviceTweakSource(remote, devices: padOnly, idiom: .pad)
        #expect(experiment().currentValue == .source("Remote", .B))
    }
    #endif

    @Test func describesOriginInCaption() {
        remote.setValue(.string("B"), forKey: "exp_paywall")
        let tweak = experiment()
        #expect(TweakCaption.text(sourceKey: "exp_paywall", reading: tweak.primitiveReading) == "Remote · exp_paywall")
        tweak.value = .C
        #expect(TweakCaption.text(sourceKey: "exp_paywall", reading: tweak.primitiveReading) == "Override · Remote: B")
        #expect(TweakCaption.text(sourceKey: nil, reading: tweak.primitiveReading) == nil)
    }
}

import Combine
import Foundation
import Testing
@testable import TweakDock
#if canImport(UIKit)
import UIKit
#endif

@Suite struct TweakSourceTests {
    enum Variant: String, CaseIterable, TweakValue { case A, B, C }

    let store = TweakStore(fileURL: FileManager.default.temporaryDirectory
        .appending(components: "TweakDockTests", "\(UUID().uuidString).json"))

    private func remote(_ values: [String: TweakPrimitive]) -> InMemoryTweakSource {
        InMemoryTweakSource(name: "Remote", values: values)
    }

    private func setRemote(_ values: [String: TweakPrimitive]) {
        store.source = remote(values)
    }

    private func experiment(_ key: String = "exp_paywall") -> Tweak<Variant> {
        Tweak(collection: "C", group: "G", name: key, defaultValue: Variant.A, sourceKey: key, store: store)
    }

    @Test func usesValidSourceValue() {
        setRemote(["exp_paywall": .string("B")])
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
        #expect(experiment().currentValue == .default(.A))
    }

    @Test func usesDefaultForUnknownVariant() {
        setRemote(["exp_paywall": .string("Z")])
        #expect(experiment().currentValue == .default(.A))
    }

    @Test func usesDefaultForValueOutsideRangeOrOptions() {
        setRemote(["retries": .string("99"), "theme": .string("blue"), "flag": .string("maybe")])
        let retries = Tweak(collection: "C", group: "G", name: "Retries", min: 0, max: 5, defaultValue: 3, sourceKey: "retries", store: store)
        let theme = Tweak(collection: "C", group: "G", name: "Theme", options: ["light", "dark"], defaultValue: "light", sourceKey: "theme", store: store)
        let flag = Tweak(collection: "C", group: "G", name: "Flag", defaultValue: false, sourceKey: "flag", store: store)
        #expect(retries.currentValue == .default(3))
        #expect(theme.currentValue == .default("light"))
        #expect(flag.currentValue == .default(false))

        setRemote(["retries": .string("4"), "theme": .string("dark"), "flag": .string("true")])
        #expect(retries.value == 4)
        #expect(theme.value == "dark")
        #expect(flag.value == true)
    }

    @Test func ignoresSourceForTweakWithoutSourceKey() {
        setRemote(["Count": .int(9)])
        let tweak = Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store)
        #expect(tweak.currentValue == .default(1))
    }

    @Test func overrideHidesSourceValueUntilReset() {
        setRemote(["exp_paywall": .string("B")])
        let tweak = experiment()
        tweak.value = .A
        #expect(tweak.currentValue == .override(.A))
        #expect(store.sourceValue(for: tweak)?.value == .B)
        tweak.reset()
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func writeOfShownValuePinsIt() {
        setRemote(["exp_paywall": .string("B")])
        let tweak = experiment()
        tweak.value = .B
        setRemote(["exp_paywall": .string("C")])
        #expect(tweak.currentValue == .override(.B))
    }

    @Test func textFieldRewriteIsNotAChange() {
        setRemote(["ratio": .double(1.23456), "limit": .int(10)])
        let ratio = Tweak(collection: "C", group: "G", name: "Ratio", defaultValue: 1.0, sourceKey: "ratio", store: store)
        let limit = Tweak(collection: "C", group: "G", name: "Limit", min: 0, max: 10, defaultValue: 5, sourceKey: "limit", store: store)
        let paywall = experiment()

        #expect(!ratio.changesValue(.double(1.235), tolerance: 0.0005))
        #expect(ratio.changesValue(.double(1.24), tolerance: 0.0005))
        #expect(!limit.changesValue(.int(15), tolerance: 0.0005))
        #expect(limit.changesValue(.int(9), tolerance: 0.0005))
        #expect(!paywall.changesValue(.string("A"), tolerance: 0.0005))
        #expect(paywall.changesValue(.string("B"), tolerance: 0.0005))
        #expect(!paywall.changesValue(.string("Z"), tolerance: 0.0005))
    }

    @Test func combinedSourceSkipsValueThatIsNotValid() {
        let launch = LaunchArgumentTweakSource(arguments: ["app", "-tweak.exp_paywall", "Z"])
        store.source = CombinedTweakSource([launch, remote(["exp_paywall": .string("B")])])
        #expect(experiment().currentValue == .source("Remote", .B))
    }

    @Test func disabledStoreIgnoresOverridesButKeepsSource() {
        setRemote(["exp_paywall": .string("B")])
        let tweak = experiment()
        tweak.value = .C
        store.isEnabled = false
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func publishesSourceChanges() {
        let tweak = experiment()
        var received: [TweakCurrentValue<Variant>] = []
        let subscription = tweak.currentValuePublisher.sink { received.append($0) }

        setRemote(["exp_paywall": .string("B")])
        setRemote(["exp_paywall": .string("Z")])
        store.source = InMemoryTweakSource(name: "Other", values: ["exp_paywall": .string("B")])

        #expect(received == [.default(.A), .source("Remote", .B), .default(.A), .source("Other", .B)])
        subscription.cancel()
    }

    @Test func combinedSourceUsesFirstValueAndItsName() {
        let launch = LaunchArgumentTweakSource(arguments: ["app", "-tweak.exp_paywall", "C"])
        store.source = CombinedTweakSource([launch, remote(["exp_paywall": .string("B"), "exp_other": .string("B")])])

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

    @Test func localSplitAssignsWhenMadeAndKeepsIt() throws {
        let suite = "TweakDockTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let source = LocalSplitTweakSource(splits: ["exp": .variants(["A": 1, "B": 1, "C": 1])], defaults: defaults)
        let bucket = try #require(defaults.object(forKey: "TweakDock.split.exp") as? Double)
        let first = source.primitive(forKey: "exp", as: .string)
        _ = LocalSplitTweakSource(splits: ["exp": .variants(["A": 1, "B": 1, "C": 1])], defaults: defaults)
        #expect(defaults.double(forKey: "TweakDock.split.exp") == bucket)
        #expect(source.primitive(forKey: "exp", as: .string) == first)
    }

    #if canImport(UIKit)
    @Test func deviceSourceGivesNoValueOnOtherDevices() {
        let remote = remote(["exp_paywall": .string("B"), "exp_other": .string("B")])
        let padOnly: [String: Set<UIUserInterfaceIdiom>] = ["exp_paywall": [.pad]]

        store.source = DeviceTweakSource(remote, devices: padOnly, idiom: .phone)
        #expect(experiment().currentValue == .default(.A))
        #expect(experiment("exp_other").currentValue == .source("Remote", .B))

        store.source = DeviceTweakSource(remote, devices: padOnly, idiom: .pad)
        #expect(experiment().currentValue == .source("Remote", .B))
    }
    #endif

    @Test func describesOriginInCaption() {
        setRemote(["exp_paywall": .string("B")])
        let tweak = experiment()
        #expect(TweakCaption.text(sourceKey: "exp_paywall", current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == "Remote · exp_paywall")
        tweak.value = .C
        #expect(TweakCaption.text(sourceKey: "exp_paywall", current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == "Override · Remote: B")
        #expect(TweakCaption.text(sourceKey: nil, current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == nil)
    }
}

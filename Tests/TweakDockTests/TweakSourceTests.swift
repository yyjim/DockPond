import Combine
import Foundation
import Testing
@testable import TweakDock

@Suite struct TweakSourceTests {
    enum Variant: String, CaseIterable, TweakValue { case A, B, C }

    let fileURL = FileManager.default.temporaryDirectory.appending(components: "TweakDockTests", "\(UUID().uuidString).json")

    private func makeStore(arguments: [String] = [], device: TweakDevices = .phone) -> TweakStore {
        TweakStore(fileURL: fileURL, isEnabled: true, arguments: arguments, device: device)
    }

    private func remote(_ values: [String: TweakPrimitive]) -> InMemoryTweakSource {
        InMemoryTweakSource(name: "Remote", values: values)
    }

    private func experiment(_ store: TweakStore, _ rule: TweakSourceRule = .remote("exp_paywall")) -> Tweak<Variant> {
        Tweak(collection: "C", group: "G", name: rule.key, defaultValue: Variant.A, source: rule, store: store)
    }

    @Test func usesValidRemoteValue() {
        let store = makeStore()
        store.remote = remote(["exp_paywall": .string("B")])
        let tweak = experiment(store)
        #expect(tweak.value == .B)
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func usesDefaultWhenRemoteHasNoValue() {
        let store = makeStore()
        #expect(experiment(store).currentValue == .default(.A))
        store.remote = remote([:])
        #expect(experiment(store).currentValue == .default(.A))
    }

    @Test func usesDefaultForUnknownVariant() {
        let store = makeStore()
        store.remote = remote(["exp_paywall": .string("Z")])
        #expect(experiment(store).currentValue == .default(.A))
    }

    @Test func usesDefaultForValueOutsideRangeOrOptions() {
        let store = makeStore()
        store.remote = remote(["retries": .string("99"), "theme": .string("blue"), "flag": .string("maybe")])
        let retries = Tweak(collection: "C", group: "G", name: "Retries", min: 0, max: 5, defaultValue: 3, source: .remote("retries"), store: store)
        let theme = Tweak(collection: "C", group: "G", name: "Theme", options: ["light", "dark"], defaultValue: "light", source: .remote("theme"), store: store)
        let flag = Tweak(collection: "C", group: "G", name: "Flag", defaultValue: false, source: .remote("flag"), store: store)
        #expect(retries.currentValue == .default(3))
        #expect(theme.currentValue == .default("light"))
        #expect(flag.currentValue == .default(false))

        store.remote = remote(["retries": .string("4"), "theme": .string("dark"), "flag": .string("true")])
        #expect(retries.value == 4)
        #expect(theme.value == "dark")
        #expect(flag.value == true)
    }

    @Test func ignoresRemoteForTweakWithoutSource() {
        let store = makeStore(arguments: ["app", "-tweak.Count", "7"])
        store.remote = remote(["Count": .int(9)])
        let tweak = Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store)
        #expect(tweak.currentValue == .default(1))
    }

    @Test func usesDefaultOnOtherDevices() {
        let phone = makeStore(device: .phone)
        let pad = makeStore(device: .pad)
        for store in [phone, pad] {
            store.remote = remote(["exp_paywall": .string("B")])
        }
        let padOnly = TweakSourceRule.remote("exp_paywall", devices: [.pad])
        #expect(experiment(phone, padOnly).currentValue == .default(.A))
        #expect(experiment(pad, padOnly).currentValue == .source("Remote", .B))
        #expect(experiment(phone).currentValue == .source("Remote", .B))
    }

    @Test func launchArgumentReplacesSourceValueOnAnyDevice() {
        let store = makeStore(arguments: ["app", "-tweak.exp_paywall", "C"], device: .phone)
        store.remote = remote(["exp_paywall": .string("B")])
        #expect(experiment(store, .remote("exp_paywall", devices: [.pad])).currentValue == .source("Launch Argument", .C))
    }

    @Test func skipsLaunchArgumentThatIsNotValid() {
        let store = makeStore(arguments: ["app", "-tweak.exp_paywall", "Z"])
        store.remote = remote(["exp_paywall": .string("B")])
        #expect(experiment(store).currentValue == .source("Remote", .B))
    }

    @Test func parsesLaunchArguments() {
        let values = TweakStore.tweakArguments(in: [
            "app", "-tweak.flag", "YES", "-tweak.empty", "-tweak.last", "L", "-other", "x",
        ])
        #expect(values == ["flag": "YES", "last": "L"])
    }

    @Test func overrideHidesSourceValueUntilReset() {
        let store = makeStore()
        store.remote = remote(["exp_paywall": .string("B")])
        let tweak = experiment(store)
        tweak.value = .A
        #expect(tweak.currentValue == .override(.A))
        #expect(store.sourceValue(for: tweak)?.value == .B)
        tweak.reset()
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func writeOfShownValuePinsIt() {
        let store = makeStore()
        store.remote = remote(["exp_paywall": .string("B")])
        let tweak = experiment(store)
        tweak.value = .B
        store.remote = remote(["exp_paywall": .string("C")])
        #expect(tweak.currentValue == .override(.B))
    }

    @Test func disabledStoreIgnoresOverridesAndLaunchArguments() {
        let store = makeStore(arguments: ["app", "-tweak.exp_paywall", "C"])
        store.remote = remote(["exp_paywall": .string("B")])
        let tweak = experiment(store)
        tweak.value = .A
        store.isEnabled = false
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func textFieldRewriteIsNotAChange() {
        let store = makeStore()
        store.remote = remote(["ratio": .double(1.23456), "limit": .int(10)])
        let ratio = Tweak(collection: "C", group: "G", name: "Ratio", defaultValue: 1.0, source: .remote("ratio"), store: store)
        let limit = Tweak(collection: "C", group: "G", name: "Limit", min: 0, max: 10, defaultValue: 5, source: .remote("limit"), store: store)
        let paywall = experiment(store)

        #expect(!ratio.changesValue(.double(1.235), tolerance: 0.0005))
        #expect(ratio.changesValue(.double(1.24), tolerance: 0.0005))
        #expect(!limit.changesValue(.int(15), tolerance: 0.0005))
        #expect(limit.changesValue(.int(9), tolerance: 0.0005))
        #expect(!paywall.changesValue(.string("A"), tolerance: 0.0005))
        #expect(paywall.changesValue(.string("B"), tolerance: 0.0005))
        #expect(!paywall.changesValue(.string("Z"), tolerance: 0.0005))
    }

    @Test func publishesRemoteChanges() {
        let store = makeStore()
        let tweak = experiment(store)
        var received: [TweakCurrentValue<Variant>] = []
        let subscription = tweak.currentValuePublisher.sink { received.append($0) }

        store.remote = remote(["exp_paywall": .string("B")])
        store.remote = remote(["exp_paywall": .string("Z")])
        store.remote = InMemoryTweakSource(name: "Other", values: ["exp_paywall": .string("B")])

        #expect(received == [.default(.A), .source("Remote", .B), .default(.A), .source("Other", .B)])
        subscription.cancel()
    }

    @Test func localSplitKeepsValueForTheSameSeed() {
        let rule = TweakSourceRule.local("lab_style", .variants(["A": 1, "B": 1, "C": 1]))
        let first = experiment(makeStore(), rule).currentValue
        guard case .source("Local Split", _) = first else {
            Issue.record("Expected a local split value, got \(first)")
            return
        }
        #expect(experiment(makeStore(), rule).currentValue == first)
    }

    @Test func localSplitUsesDefaultOnOtherDevices() {
        let rule = TweakSourceRule.local("lab_style", .variants(["B": 1]), devices: [.pad])
        #expect(experiment(makeStore(device: .phone), rule).currentValue == .default(.A))
        #expect(experiment(makeStore(device: .pad), rule).currentValue == .source("Local Split", .B))
    }

    @Test func localSplitConvertsTextVariants() {
        let store = makeStore()
        let limit = Tweak(collection: "C", group: "G", name: "Limit", defaultValue: 0, source: .local("lab_limit", .variants(["3": 1])), store: store)
        #expect(limit.currentValue == .source("Local Split", 3))
    }

    @Test func splitMapsBucketsByWeight() {
        let split = TweakSplit.variants(["A": 1, "B": 1, "C": 2])
        #expect(split.value(at: 0.1) == .string("A"))
        #expect(split.value(at: 0.3) == .string("B"))
        #expect(split.value(at: 0.9) == .string("C"))
        #expect(TweakSplit.rollout(0.2).value(at: 0.1) == .bool(true))
        #expect(TweakSplit.rollout(0.2).value(at: 0.3) == .bool(false))
        #expect(TweakSplit.rollout(0.5).value(at: 0.3) == .bool(true))
        #expect(TweakSplit.rollout(0).value(at: 0) == .bool(false))
    }

    @Test func splitBucketIsStableAndSpread() {
        #expect(TweakSplit.bucket(seed: "s", key: "k") == TweakSplit.bucket(seed: "s", key: "k"))
        let buckets = (0 ..< 1000).map { TweakSplit.bucket(seed: "seed-\($0)", key: "k") }
        #expect(buckets.allSatisfy { (0 ..< 1).contains($0) })
        #expect((400 ... 600).contains(buckets.filter { $0 < 0.5 }.count))
    }

    @Test func resetSplitsGivesNewValuesAndKeepsThem() {
        let store = makeStore()
        let rules = (0 ..< 20).map { TweakSourceRule.local("lab_\($0)", .variants(["A": 1, "B": 1, "C": 1])) }
        let before = rules.map { experiment(store, $0).value }
        store.resetSplits()
        let after = rules.map { experiment(store, $0).value }
        #expect(after != before)
        #expect(rules.map { experiment(makeStore(), $0).value } == after)
    }

    @Test func describesSourceInCaption() {
        let store = makeStore()
        store.remote = remote(["exp_paywall": .string("B")])
        let tweak = experiment(store)
        #expect(TweakCaption.text(key: "exp_paywall", current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == "Remote · exp_paywall")
        tweak.value = .C
        #expect(TweakCaption.text(key: "exp_paywall", current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == "Override · Remote: B")
        #expect(TweakCaption.text(key: nil, current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == nil)
    }
}

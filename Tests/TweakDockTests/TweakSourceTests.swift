import Combine
import Foundation
import Testing
@testable import TweakDock

@Suite struct TweakSourceTests {
    enum Variant: String, CaseIterable, TweakValue { case A, B, C }

    let fileURL = FileManager.default.temporaryDirectory.appending(components: "TweakDockTests", "\(UUID().uuidString).json")

    private func makeStore(
        arguments: [String] = [], device: TweakDevices = .phone,
        remote: [String: TweakPrimitive]? = nil
    ) -> TweakStore {
        let provider = remote.map { InMemoryValueProvider(name: "Remote", values: $0) }
        return makeStore(arguments: arguments, device: device, provider: provider)
    }

    private func makeStore(
        arguments: [String] = [], device: TweakDevices = .phone, provider: (any TweakValueProvider)?
    ) -> TweakStore {
        TweakStore(fileURL: fileURL, isEnabled: true, arguments: arguments, device: device, experimentProvider: provider)
    }

    private func experiment(_ store: TweakStore, _ source: TweakSource = .experiment("exp_paywall")) -> Tweak<Variant> {
        Tweak(collection: "C", group: "G", name: source.key, defaultValue: Variant.A, from: source, store: store)
    }

    @Test func usesValidRemoteValue() {
        let tweak = experiment(makeStore(remote: ["exp_paywall": .string("B")]))
        #expect(tweak.value == .B)
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func usesDefaultWhenRemoteHasNoValue() {
        #expect(experiment(makeStore()).currentValue == .default(.A))
        #expect(experiment(makeStore(remote: [:])).currentValue == .default(.A))
    }

    @Test func usesDefaultForUnknownVariant() {
        #expect(experiment(makeStore(remote: ["exp_paywall": .string("Z")])).currentValue == .default(.A))
    }

    @Test func usesDefaultForValueOutsideRangeOrOptions() {
        let remote = TestProvider(values: ["retries": .string("99"), "theme": .string("blue"), "flag": .string("maybe")])
        let store = makeStore(provider: remote)
        let retries = Tweak(collection: "C", group: "G", name: "Retries", min: 0, max: 5, defaultValue: 3, from: .experiment("retries"), store: store)
        let theme = Tweak(collection: "C", group: "G", name: "Theme", options: ["light", "dark"], defaultValue: "light", from: .experiment("theme"), store: store)
        let flag = Tweak(collection: "C", group: "G", name: "Flag", defaultValue: false, from: .experiment("flag"), store: store)
        #expect(retries.currentValue == .default(3))
        #expect(theme.currentValue == .default("light"))
        #expect(flag.currentValue == .default(false))

        remote.values = ["retries": .string("4"), "theme": .string("dark"), "flag": .string("true")]
        #expect(retries.value == 4)
        #expect(theme.value == "dark")
        #expect(flag.value == true)
    }

    @Test func ignoresRemoteForTweakWithoutSource() {
        let store = makeStore(arguments: ["app", "-tweak.Count", "7"], remote: ["Count": .int(9)])
        let tweak = Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store)
        #expect(tweak.currentValue == .default(1))
    }

    @Test func usesDefaultOnOtherDevices() {
        let phone = makeStore(device: .phone, remote: ["exp_paywall": .string("B")])
        let pad = makeStore(device: .pad, remote: ["exp_paywall": .string("B")])
        let padOnly = TweakSource.experiment("exp_paywall", devices: [.pad])
        #expect(experiment(phone, padOnly).currentValue == .default(.A))
        #expect(experiment(pad, padOnly).currentValue == .source("Remote", .B))
        #expect(experiment(phone).currentValue == .source("Remote", .B))
    }

    @Test func launchArgumentReplacesSourceValueOnAnyDevice() {
        let store = makeStore(arguments: ["app", "-tweak.exp_paywall", "C"], device: .phone, remote: ["exp_paywall": .string("B")])
        #expect(experiment(store, .experiment("exp_paywall", devices: [.pad])).currentValue == .source("Launch Argument", .C))
    }

    @Test func skipsLaunchArgumentThatIsNotValid() {
        let store = makeStore(arguments: ["app", "-tweak.exp_paywall", "Z"], remote: ["exp_paywall": .string("B")])
        #expect(experiment(store).currentValue == .source("Remote", .B))
    }

    @Test func parsesLaunchArguments() {
        let values = TweakStore.tweakArguments(in: [
            "app", "-tweak.flag", "YES", "-tweak.empty", "-tweak.last", "L", "-other", "x",
        ])
        #expect(values == ["flag": "YES", "last": "L"])
    }

    @Test func overrideHidesSourceValueUntilReset() {
        let store = makeStore(remote: ["exp_paywall": .string("B")])
        let tweak = experiment(store)
        tweak.value = .A
        #expect(tweak.currentValue == .override(.A))
        #expect(store.sourceValue(for: tweak)?.value == .B)
        tweak.reset()
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func writeOfShownValuePinsIt() {
        let remote = TestProvider(values: ["exp_paywall": .string("B")])
        let tweak = experiment(makeStore(provider: remote))
        tweak.value = .B
        remote.values = ["exp_paywall": .string("C")]
        #expect(tweak.currentValue == .override(.B))
    }

    @Test func disabledStoreIgnoresOverridesAndLaunchArguments() {
        let store = makeStore(arguments: ["app", "-tweak.exp_paywall", "C"], remote: ["exp_paywall": .string("B")])
        let tweak = experiment(store)
        tweak.value = .A
        store.isEnabled = false
        #expect(tweak.currentValue == .source("Remote", .B))
    }

    @Test func publishesProviderChanges() {
        let remote = TestProvider()
        let tweak = experiment(makeStore(provider: remote))
        var received: [TweakCurrentValue<Variant>] = []
        let subscription = tweak.currentValuePublisher.sink { received.append($0) }

        remote.values = ["exp_paywall": .string("B")]
        remote.values = ["exp_paywall": .string("Z")]
        remote.values = ["exp_paywall": .string("C")]

        #expect(received == [.default(.A), .source("Remote", .B), .default(.A), .source("Remote", .C)])
        subscription.cancel()
    }

    @Test func listsExperimentProperties() {
        let store = makeStore(device: .phone, remote: ["exp_paywall": .string("B"), "exp_pad": .string("B"), "exp_limit": .string("12")])
        let pinned = experiment(store, .experiment("exp_pinned"))
        pinned.value = .C
        let tweaks: [any AnyTweak] = [
            experiment(store),
            experiment(store, .experiment("exp_pad", devices: [.pad])),
            pinned,
            Tweak(collection: "C", group: "G", name: "Limit", defaultValue: 5, from: .experiment("exp_limit"), store: store),
            Tweak(collection: "C", group: "G", name: "Plain", defaultValue: 1, store: store),
        ]
        #expect(tweaks.experimentProperties == [
            "exp_paywall": "B", "exp_pad": "default", "exp_pinned": "C", "exp_limit": "12",
        ])
    }

    @Test func describesSourceInCaption() {
        let store = makeStore(remote: ["exp_paywall": .string("B")])
        let tweak = experiment(store)
        #expect(TweakCaption.text(key: "exp_paywall", current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == "Remote · exp_paywall")
        tweak.value = .C
        #expect(TweakCaption.text(key: "exp_paywall", current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == "Override · Remote: B")
        #expect(TweakCaption.text(key: nil, current: tweak.primitiveCurrentValue, source: tweak.primitiveSourceValue) == nil)
    }
}

/// Tests change the values on one thread only.
private final class TestProvider: TweakValueProvider, @unchecked Sendable {
    let name = "Remote"
    private let subject = PassthroughSubject<Void, Never>()
    var values: [String: TweakPrimitive] {
        didSet { subject.send() }
    }

    init(values: [String: TweakPrimitive] = [:]) {
        self.values = values
    }

    func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? { values[key]?.converted(to: kind) }
    var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
}

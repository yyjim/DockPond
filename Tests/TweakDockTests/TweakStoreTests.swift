import Combine
import Foundation
import Testing
@testable import TweakDock

@Suite struct TweakStoreTests {
    enum Mode: String, CaseIterable, TweakValue { case fast, slow }

    let fileURL: URL
    let store: TweakStore

    init() {
        fileURL = FileManager.default.temporaryDirectory
            .appending(components: "TweakDockTests", "\(UUID().uuidString).json")
        store = TweakStore(fileURL: fileURL)
    }

    @Test func returnsDefaultUntilSet() {
        let tweak = Tweak(collection: "C", group: "G", name: "Flag", defaultValue: false, store: store)
        #expect(tweak.value == false)
        tweak.value = true
        #expect(tweak.value == true)
        tweak.reset()
        #expect(tweak.value == false)
    }

    @Test func persistsAcrossStores() {
        Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store).value = 5
        let reloaded = TweakStore(fileURL: fileURL)
        #expect(Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: reloaded).value == 5)
    }

    @Test func clampsValuesToRange() {
        let tweak = Tweak(collection: "C", group: "G", name: "Size", min: 10.0, max: 20.0, defaultValue: 12.0, store: store)
        tweak.value = 15
        #expect(tweak.value == 15)
        tweak.value = 99
        #expect(tweak.value == 20)
        tweak.value = -5
        #expect(tweak.value == 10)
        #expect(tweak.control == .number(range: 10 ... 20))
    }

    @Test func clampsStoredValueAfterRangeShrinks() {
        Tweak(collection: "C", group: "G", name: "Size", min: 0, max: 100, defaultValue: 1, store: store).value = 50
        let narrower = Tweak(collection: "C", group: "G", name: "Size", min: 0, max: 10, defaultValue: 1, store: store)
        #expect(narrower.value == 10)
    }

    @Test func supportsStringOptionsAndEnums() {
        let theme = Tweak(collection: "C", group: "G", name: "Theme", options: ["a", "b"], defaultValue: "a", store: store)
        theme.value = "b"
        #expect(theme.value == "b")
        theme.value = "z"
        #expect(theme.value == "a")

        let mode = Tweak(collection: "C", group: "G", name: "Mode", defaultValue: Mode.fast, store: store)
        mode.value = .slow
        #expect(mode.value == .slow)
        #expect(mode.control == .picker(options: ["fast", "slow"]))
    }

    @Test func returnsDefaultsWhenDisabled() {
        let tweak = Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store)
        tweak.value = 3
        store.isEnabled = false
        #expect(tweak.value == 1)
        store.isEnabled = true
        #expect(tweak.value == 3)
    }

    @Test func publishesCurrentValueThenChanges() {
        let tweak = Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store)
        let other = Tweak(collection: "C", group: "G", name: "Other", defaultValue: 1, store: store)
        var received: [Int] = []
        let subscription = tweak.publisher.sink { received.append($0) }

        tweak.value = 2
        tweak.value = 2
        other.value = 9
        store.resetAll()

        #expect(received == [1, 2, 1])
        subscription.cancel()
    }

    @Test func storesNoOverrideForDefaultValue() {
        let tweak = Tweak(collection: "C", group: "G", name: "Count", defaultValue: 1, store: store)
        tweak.value = 2
        tweak.value = 1
        let saved = try? JSONDecoder().decode([String: TweakPrimitive].self, from: Data(contentsOf: fileURL))
        #expect(saved == [:])
    }
}

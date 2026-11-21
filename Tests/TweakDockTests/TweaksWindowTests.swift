import Foundation
import Testing
@testable import TweakDock

@Suite struct TweaksWindowTests {
    private func store() -> TweakStore {
        TweakStore(fileURL: FileManager.default
            .temporaryDirectory
            .appending(components: "TweakDockTests", "\(UUID().uuidString).json"))
    }

    private func tweak(in store: TweakStore) -> any AnyTweak {
        Tweak(collection: "C", group: "G", name: UUID().uuidString, defaultValue: 0, store: store)
    }

    @Test func enablesWhenAStoreOfTheTweaksIsEnabled() {
        let app = store(), experiments = store()
        let tweaks = [tweak(in: app), tweak(in: experiments)]
        #expect(tweaks.hasEnabledStore)

        app.isEnabled = false
        #expect(tweaks.hasEnabledStore)

        experiments.isEnabled = false
        #expect(!tweaks.hasEnabledStore)
    }

    @Test func ignoresStoresWithoutTweaksInTheList() {
        let experiments = store()
        experiments.isEnabled = false
        #expect(TweakStore.shared.isEnabled)
        #expect(![tweak(in: experiments)].hasEnabledStore)
    }

    @Test func usesTheStoreOfActions() {
        let custom = store()
        let actions: [any AnyTweak] = [TweakAction(collection: "C", group: "G", name: "Run", store: custom) {}]
        #expect(actions.hasEnabledStore)

        custom.isEnabled = false
        #expect(TweakStore.shared.isEnabled)
        #expect(!actions.hasEnabledStore)
    }
}

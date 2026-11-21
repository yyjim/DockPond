import Foundation
import Testing
@testable import TweakDock

extension TweakStore {
    static let generated = TweakStore(
        fileURL: FileManager.default.temporaryDirectory.appending(components: "TweakDockTests", "\(UUID().uuidString).json"),
        isEnabled: true,
        arguments: [],
        device: .phone,
        experimentProvider: InMemoryValueProvider(
            name: "Remote",
            values: ["gen_paywall": .string("B"), "gen_ipad_sidebar": .string("A"), "gen_keyword": .string("default")]
        )
    )
}

@Suite struct GeneratedExperimentsTests {
    @Test func listsTheExperimentsInFileOrder() {
        #expect(GeneratedExperiments.allTweaks.map(\.name) == [
            "gen_paywall", "gen_ipad_sidebar", "gen_magic_erase", "gen_keyword", "default"
        ])
        #expect(GeneratedExperiments.allTweaks.map(\.group) == ["A/B Tests", "A/B Tests", "A/B Tests", "Lab", "A/B Tests"])
    }

    @Test func readsTheRemoteValues() {
        #expect(GeneratedExperiments.genPaywall == .B)
        #expect(GeneratedExperiments.genKeyword == .default)
    }

    @Test func compilesAKeywordKey() {
        #expect(GeneratedExperiments.`default` == .A)
        #expect(GeneratedExperiments.defaultTweak.name == "default")
    }

    @Test func usesTheDefaultOnOtherDevices() {
        #expect(GeneratedExperiments.genIpadSidebar == .B)
    }

    @Test func usesTheDefaultWithoutARemoteValue() {
        #expect(GeneratedExperiments.genMagicEraseTweak.currentValue == .default(.off))
        #expect(GeneratedExperiments.GenMagicErase.allCases == [.on, .off])
    }

    @Test func reportsTheExperimentProperties() {
        #expect(GeneratedExperiments.allTweaks.experimentProperties == [
            "gen_paywall": "B",
            "gen_ipad_sidebar": "default",
            "gen_magic_erase": "default",
            "gen_keyword": "default",
            "default": "default"
        ])
    }
}

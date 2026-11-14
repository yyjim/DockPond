#if canImport(TweakDockMacros)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import TweakDockMacros
import XCTest

private let macros: [String: Macro.Type] = ["Tweak": TweakMacro.self, "Tweaks": TweaksMacro.self]

final class TweakMacroTests: XCTestCase {
    func testExpandsPropertyAndList() {
        assertMacroExpansion(
            """
            @Tweaks
            public enum AppTweaks {
                @Tweak(collection: "UI", group: "Font", name: "Size", min: 10, max: 40, defaultValue: 14)
                public static var fontSize: CGFloat

                @Tweak(collection: "Debug", group: "Session", name: "Clear Cache")
                static func clearCache() {}
            }
            """,
            expandedSource: """
            public enum AppTweaks {
                public static var fontSize: CGFloat {
                    get {
                        fontSizeTweak.value
                    }
                    set {
                        fontSizeTweak.value = newValue
                    }
                }

                public static let fontSizeTweak = Tweak<CGFloat>(collection: "UI", group: "Font", name: "Size", min: 10, max: 40, defaultValue: 14, store: tweakStore)
                static func clearCache() {}

                static let clearCacheTweak = TweakAction(collection: "Debug", group: "Session", name: "Clear Cache") {
                    clearCache()
                }

                public static let tweakStore: TweakStore = .shared

                public static let allTweaks: [any AnyTweak] = [fontSizeTweak, clearCacheTweak]
            }
            """,
            macros: macros
        )
    }

    func testUsesGivenStore() {
        assertMacroExpansion(
            """
            @Tweaks(store: .appGroup)
            enum AppTweaks {
                @Tweak(collection: "C", group: "G", name: "N", defaultValue: true)
                static var flag: Bool
            }
            """,
            expandedSource: """
            enum AppTweaks {
                static var flag: Bool {
                    get {
                        flagTweak.value
                    }
                    set {
                        flagTweak.value = newValue
                    }
                }

                static let flagTweak = Tweak<Bool>(collection: "C", group: "G", name: "N", defaultValue: true, store: tweakStore)

                static let tweakStore: TweakStore = .appGroup

                static let allTweaks: [any AnyTweak] = [flagTweak]
            }
            """,
            macros: macros
        )
    }

    func testCopiesPackageAccessToMembers() {
        assertMacroExpansion(
            """
            @Tweaks
            package enum AppTweaks {
            }
            """,
            expandedSource: """
            package enum AppTweaks {

                package static let tweakStore: TweakStore = .shared

                package static let allTweaks: [any AnyTweak] = []
            }
            """,
            macros: macros
        )
    }

    func testGivesOpenTypesPublicMembers() {
        assertMacroExpansion(
            """
            @Tweaks
            open class AppTweaks {
            }
            """,
            expandedSource: """
            open class AppTweaks {

                public static let tweakStore: TweakStore = .shared

                public static let allTweaks: [any AnyTweak] = []
            }
            """,
            macros: macros
        )
    }

    func testUsesTheAccessOfAnEnclosingExtension() {
        assertMacroExpansion(
            """
            public extension Namespace {
                @Tweaks
                enum AppTweaks {
                }
            }
            """,
            expandedSource: """
            public extension Namespace {
                enum AppTweaks {

                    public static let tweakStore: TweakStore = .shared

                    public static let allTweaks: [any AnyTweak] = []
                }
            }
            """,
            macros: macros
        )
    }

    func testDropsSetterAccessFromPeer() {
        assertMacroExpansion(
            """
            @Tweak(collection: "C", group: "G", name: "N", defaultValue: true)
            public private(set) static var flag: Bool
            """,
            expandedSource: """
            public private(set) static var flag: Bool {
                get {
                    flagTweak.value
                }
                set {
                    flagTweak.value = newValue
                }
            }

            public static let flagTweak = Tweak<Bool>(collection: "C", group: "G", name: "N", defaultValue: true, store: tweakStore)
            """,
            macros: macros
        )
    }

    func testListsTweaksInConditionalBlocks() {
        assertMacroExpansion(
            """
            @Tweaks
            enum AppTweaks {
                @Tweak(collection: "C", group: "G", name: "A", defaultValue: true)
                static var a: Bool
                #if DEBUG
                @Tweak(collection: "C", group: "G", name: "B", defaultValue: true)
                static var b: Bool
                #else
                static var unrelated = 1
                #endif
            }
            """,
            expandedSource: """
            enum AppTweaks {
                static var a: Bool {
                    get {
                        aTweak.value
                    }
                    set {
                        aTweak.value = newValue
                    }
                }

                static let aTweak = Tweak<Bool>(collection: "C", group: "G", name: "A", defaultValue: true, store: tweakStore)
                #if DEBUG
                static var b: Bool {
                    get {
                        bTweak.value
                    }
                    set {
                        bTweak.value = newValue
                    }
                }
                #else
                static var unrelated = 1
                #endif

                static let tweakStore: TweakStore = .shared

                static let allTweaks: [any AnyTweak] = {
                    var tweaks: [any AnyTweak] = []
                    tweaks.append(aTweak)
                    #if DEBUG
                    tweaks.append(bTweak)
                    #else
                    #endif
                    return tweaks
                }()
            }
            """,
            macros: macros
        )
    }

    func testListsOnlyValidTweaks() {
        assertMacroExpansion(
            """
            @Tweaks
            enum AppTweaks {
                @Tweak(collection: "C", group: "G", name: "N", defaultValue: true)
                var flag: Bool
            }
            """,
            expandedSource: """
            enum AppTweaks {
                var flag: Bool

                static let tweakStore: TweakStore = .shared

                static let allTweaks: [any AnyTweak] = []
            }
            """,
            diagnostics: [DiagnosticSpec(message: "@Tweak property 'flag' must be static.", line: 3, column: 5)],
            macros: macros
        )
    }

    func testRejectsInstanceProperty() {
        assertMacroExpansion(
            """
            @Tweak(collection: "C", group: "G", name: "N", defaultValue: true)
            var flag: Bool
            """,
            expandedSource: """
            var flag: Bool
            """,
            diagnostics: [DiagnosticSpec(message: "@Tweak property 'flag' must be static.", line: 1, column: 1)],
            macros: macros
        )
    }

    func testRejectsInitialValue() {
        assertMacroExpansion(
            """
            @Tweak(collection: "C", group: "G", name: "N", defaultValue: true)
            static var flag: Bool = true
            """,
            expandedSource: """
            static var flag: Bool = true
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Tweak property 'flag' must not have a value. Use 'defaultValue' instead.", line: 1, column: 1),
            ],
            macros: macros
        )
    }

    func testRejectsActionWithParameters() {
        assertMacroExpansion(
            """
            @Tweak(collection: "C", group: "G", name: "N")
            static func run(_ value: Int) {}
            """,
            expandedSource: """
            static func run(_ value: Int) {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Tweak method 'run' must take no parameters, return nothing, and not throw or be async.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: macros
        )
    }
}
#endif

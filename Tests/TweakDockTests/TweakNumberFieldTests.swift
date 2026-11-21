import Testing
@testable import TweakDock

struct TweakNumberFieldTests {
    @Test func givesTheValueThatTheTextFieldShows() {
        for value in [0.0015, 0.1235, 2.0004, 0.5, 3] {
            let shown = TweakNumberField.shown(value)
            #expect(shown == TweakNumberField.shown(shown))
            #expect(abs(shown - value) <= 0.0005 + 1e-12)
        }
        #expect(TweakNumberField.shown(2.0004) == 2)
    }
}

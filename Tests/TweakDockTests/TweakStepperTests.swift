import Testing
@testable import TweakDock

struct TweakStepperTests {
    @Test func keepsTheSwiftTweaksRule() {
        #expect(TweakStepper.stepSize(defaultValue: 0.5, isInteger: false, range: 0 ... 1) == 0.01)
        #expect(TweakStepper.stepSize(defaultValue: 12, isInteger: false, range: 10 ... 20) == 1)
        #expect(TweakStepper.stepSize(defaultValue: 2, isInteger: false, range: nil) == 1)
        #expect(TweakStepper.stepSize(defaultValue: 2, isInteger: true, range: 0 ... 5) == 1)
    }

    @Test func usesASmallerStepForANarrowFractionalRange() {
        #expect(TweakStepper.stepSize(defaultValue: 1, isInteger: false, range: 0.6 ... 1.4) == 0.1)
        #expect(TweakStepper.stepSize(defaultValue: 1, isInteger: false, range: 0 ... 3) == 0.1)
        #expect(TweakStepper.stepSize(defaultValue: 1, isInteger: false, range: 1 ... 1.2) == 0.01)
    }
}

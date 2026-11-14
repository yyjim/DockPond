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

    @Test func trimsFloatingPointErrorFromSteps() {
        #expect(TweakStepper.trimmed(1.0 - 0.1 - 0.1 - 0.1, step: 0.1) == 0.7)
        #expect(TweakStepper.trimmed(0.1 + 0.2, step: 0.01) == 0.3)
        #expect(TweakStepper.trimmed(-2.5, step: 1) == -2.5)
    }

    @Test func keepsLargeAndPreciseValues() {
        #expect(TweakStepper.trimmed(1e12 + 1, step: 1) == 1e12 + 1)
        #expect(TweakStepper.trimmed(1_234_567.123456, step: 1) == 1_234_567.123456)
        #expect(TweakStepper.trimmed(1e300, step: 1) == 1e300)
    }
}

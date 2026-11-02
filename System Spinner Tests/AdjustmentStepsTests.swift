//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Testing
@testable import System_Spinner

@Suite("Adjustment steps")
struct AdjustmentStepsTests {
    @Test("Fine adjustment is the coarsest step count offered in the menu")
    func fineStepsMatchMenu() {
        #expect(Preferences.fineAdjustmentSteps == 32)
        #expect(Preferences.adjustmentStepChoices.max() == Preferences.fineAdjustmentSteps)
    }

    @Test("Without the modifier the preference is used as is", arguments: [8, 16, 24, 32])
    func plainStepsFollowPreference(base: Int) {
        #expect(Preferences.adjustmentSteps(base: base, fine: false) == base)
    }

    @Test("The modifier widens the scale to 32 steps", arguments: [8, 16, 24, 32])
    func fineStepsWidenScale(base: Int) {
        #expect(Preferences.adjustmentSteps(base: base, fine: true) == 32)
    }

    @Test("A preference finer than 32 steps is never coarsened")
    func fineStepsNeverShrink() {
        #expect(Preferences.adjustmentSteps(base: 64, fine: true) == 64)
    }

    @Test("The OSD carries the widened scale")
    func osdCarriesFineScale() {
        let steps = Preferences.adjustmentSteps(base: 16, fine: true)
        #expect(OSDValue(value: 50, kind: .displayBrightness, separatorSteps: steps).separatorSteps == 32)
    }
}

@Suite("Reduced last step")
struct ReducedLastStepTests {
    @Test("The last step is split according to the step count", arguments: [
        (8, 5), (16, 3), (24, 2), (32, 1),
    ])
    func divisions(steps: Int, expected: Int) {
        #expect(AdjustmentScale(steps: steps, reducesLastStep: true).lastStepDivisions == expected)
        #expect(AdjustmentScale(steps: steps, reducesLastStep: false).lastStepDivisions == 1)
    }

    @Test("Levels start at 0 with a finer first step")
    func levels() {
        let levels = AdjustmentScale(steps: 8, reducesLastStep: true).levels
        #expect(levels.count == 5 + 8)
        #expect(levels.first == 0)
        #expect(levels[1] == 2.5)
        #expect(levels[5] == 12.5)
        #expect(levels.last == 100)
    }

    @Test("Stepping up and down walks the refined levels")
    func stepping() {
        let scale = AdjustmentScale(steps: 16, reducesLastStep: true)
        let third: Float = 6.25 / 3
        #expect(scale.next(from: 12.5, isUp: false) == 6.25)
        #expect(scale.next(from: 6.25, isUp: false) == third * 2)
        #expect(scale.next(from: third * 2, isUp: false) == third)
        #expect(scale.next(from: third, isUp: false) == 0)
        #expect(scale.next(from: 0, isUp: true) == third)
        #expect(scale.next(from: 100, isUp: true) == 100)
        #expect(scale.next(from: 100, isUp: false) == 93.75)
    }

    @Test("Without the option the scale matches plain steps")
    func plain() {
        let scale = AdjustmentScale(steps: 16)
        #expect(scale.next(from: 93.75, isUp: true) == 100)
        #expect(scale.next(from: 50, isUp: false) == 43.75)
    }
}

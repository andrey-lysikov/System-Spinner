//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Testing
@testable import System_Spinner

@Suite("OSD value")
struct OSDValueTests {
    @Test("Value is clamped to the 0...100 range", arguments: [
        (Float(-10), Float(0)),
        (0, 0),
        (42, 42),
        (100, 100),
        (150, 100),
    ])
    func clamping(input: Float, expected: Float) {
        #expect(OSDValue(value: input).value == expected)
    }

    @Test("Volume icon follows the level", arguments: [
        (Float(0), "speaker.slash.fill"),
        (1, "speaker.wave.1.fill"),
        (32, "speaker.wave.1.fill"),
        (33, "speaker.wave.2.fill"),
        (65, "speaker.wave.2.fill"),
        (66, "speaker.wave.3.fill"),
        (100, "speaker.wave.3.fill"),
    ])
    func volumeIcon(value: Float, expected: String) {
        #expect(OSDValue(value: value, isDisplay: false).iconName == expected)
    }

    @Test("Brightness icon switches at 80", arguments: [
        (Float(0), "sun.min"),
        (79, "sun.min"),
        (80, "sun.max"),
        (100, "sun.max"),
    ])
    func brightnessIcon(value: Float, expected: String) {
        #expect(OSDValue(value: value, isDisplay: true).iconName == expected)
    }

    @Test("Default separator count matches the default preference")
    func defaultSeparators() {
        #expect(OSDValue().separatorSteps == 16)
    }
}

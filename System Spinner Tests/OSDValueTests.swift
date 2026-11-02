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
        #expect(OSDValue(value: value, kind: .volume).iconName == expected)
    }

    @Test("Brightness icon switches at 80", arguments: [
        (Float(0), "sun.min"),
        (79, "sun.min"),
        (80, "sun.max"),
        (100, "sun.max"),
    ])
    func brightnessIcon(value: Float, expected: String) {
        #expect(OSDValue(value: value, kind: .displayBrightness).iconName == expected)
    }

    @Test("Keyboard backlight icon is filled while the backlight is on", arguments: [
        (Float(0), "keyboard"),
        (1, "keyboard.fill"),
        (100, "keyboard.fill"),
    ])
    func keyboardBacklightIcon(value: Float, expected: String) {
        #expect(OSDValue(value: value, kind: .keyboardBacklight).iconName == expected)
    }

    @Test("Default separator count matches the default preference")
    func defaultSeparators() {
        #expect(OSDValue().separatorSteps == 16)
    }
}

@Suite("Displayed volume")
struct DisplayedVolumeTests {
    @Test("A muted output is shown as silent whatever its level", arguments: [Float(0), 37, 100])
    func mutedIsSilent(level: Float) {
        #expect(OSDValue.volume(level, isMuted: true).value == 0)
        #expect(OSDValue.volume(level, isMuted: true).iconName == "speaker.slash.fill")
    }

    @Test("An unmuted output is shown at its level", arguments: [
        (Float(0), Float(0)),
        (37, 37),
        (100, 100),
    ])
    func unmutedShowsLevel(level: Float, expected: Float) {
        #expect(OSDValue.volume(level, isMuted: false, separators: 24).value == expected)
        #expect(OSDValue.volume(level, isMuted: false, separators: 24).separatorSteps == 24)
    }

    @Test("An unreadable level is shown as silent")
    func unreadableIsSilent() {
        #expect(OSDValue.volume(-100, isMuted: false).value == 0)
    }
}

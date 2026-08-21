//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Testing
@testable import System_Spinner

@Suite("Version numbers")
struct UpdateCheckerTests {
    @Test("Digits are collected into a comparable number", arguments: [
        ("4.7.0", 470),
        ("5.0.0", 500),
        ("v4.7.0", 470),
        ("Version 4.7.0", 470),
    ])
    func parsing(tag: String, expected: Int) {
        #expect(UpdateChecker.versionNumber(tag) == expected)
    }

    @Test("A tag without digits reads as zero", arguments: ["", "latest", "vX.Y.Z"])
    func noDigits(tag: String) {
        #expect(UpdateChecker.versionNumber(tag) == 0)
    }

    @Test("A newer release compares greater than the installed one")
    func ordering() {
        #expect(UpdateChecker.versionNumber("5.0.0") > UpdateChecker.versionNumber("4.7.0"))
        #expect(UpdateChecker.versionNumber("4.7.1") > UpdateChecker.versionNumber("4.7.0"))
        #expect(UpdateChecker.versionNumber("4.7.0") == UpdateChecker.versionNumber("4.7.0"))
    }

    @Test("Known limitation: digits alone cannot tell these apart")
    func knownCollision() {
        // Comparing by concatenated digits treats these as equal. It holds for
        // the numbering in use, but the test records the boundary.
        #expect(UpdateChecker.versionNumber("4.10.0") == UpdateChecker.versionNumber("41.0.0"))
    }
}

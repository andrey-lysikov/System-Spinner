//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Testing
@testable import System_Spinner

private let kilobyte = 1024.0
private let megabyte = kilobyte * kilobyte
private let gigabyte = megabyte * kilobyte
private let terabyte = gigabyte * kilobyte

@Suite("Network throughput")
struct ThroughputTests {
    @Test("Bytes below a megabyte are shown in kilobytes")
    func kilobytes() {
        let throughput = Throughput(bytesPerSecond: 2 * kilobyte)

        #expect(throughput.unit == .kilobytes)
        #expect(throughput.value == 2)
    }

    @Test("Zero traffic stays in kilobytes")
    func zero() {
        #expect(Throughput.zero.unit == .kilobytes)
        #expect(Throughput.zero.value == 0)
    }

    @Test("Unit follows the amount of traffic", arguments: [
        (1.0, Throughput.Unit.kilobytes),
        (kilobyte, .kilobytes),
        (megabyte, .megabytes),
        (gigabyte, .gigabytes),
        (terabyte, .terabytes),
    ])
    func unitForAmount(bytes: Double, expected: Throughput.Unit) {
        #expect(Throughput(bytesPerSecond: bytes).unit == expected)
    }

    @Test("Value is scaled down to the chosen unit")
    func scaling() {
        let throughput = Throughput(bytesPerSecond: 3 * megabyte)

        #expect(throughput.unit == .megabytes)
        #expect(throughput.value == 3)
    }

    @Test("Raw byte rate is kept as given")
    func keepsRawRate() {
        let throughput = Throughput(bytesPerSecond: 1536)

        #expect(throughput.bytesPerSecond == 1536)
        #expect(throughput.value == 1.5)
    }
}

//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import System_Spinner

@Suite("External address parsing")
struct ExternalAddressTests {
    private func parse(_ html: String) -> String? {
        NetworkMonitor.parseExternalAddress(from: Data(html.utf8))
    }

    @Test("Address is taken from the checkip response")
    func realResponse() {
        let html = "<html><head><title>Current IP Check</title></head>"
            + "<body>Current IP Address: 203.0.113.42</body></html>"

        #expect(parse(html) == "203.0.113.42")
    }

    @Test("Surrounding whitespace is trimmed")
    func trimsWhitespace() {
        #expect(parse("Current IP Address:   198.51.100.7 </body>") == "198.51.100.7")
    }

    @Test("IPv6 addresses survive the parsing")
    func ipv6() {
        #expect(parse("Current IP Address: 2001:db8::1</body>") == "2001:db8::1")
    }

    @Test("Responses without the marker yield nothing", arguments: [
        "<html><body>Service unavailable</body></html>",
        "",
        "Current IP: 203.0.113.42",
    ])
    func missingMarker(html: String) {
        #expect(parse(html) == nil)
    }

    @Test("An empty address is treated as no address")
    func emptyAddress() {
        #expect(parse("Current IP Address: </body>") == nil)
    }

    @Test("Binary junk does not crash the parser")
    func binaryData() {
        let data = Data([0xFF, 0xFE, 0x00, 0x01])

        #expect(NetworkMonitor.parseExternalAddress(from: data) == nil)
    }
}

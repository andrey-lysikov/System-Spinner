//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation

final class NetworkMonitor: @unchecked Sendable {
    private let queue: DispatchQueue
    private var previousInBytes: UInt64 = 0
    private var previousOutBytes: UInt64 = 0
    private var hasBaseline = false
    private var localAddress = ""
    private var externalAddress = ""
    private var isLookingUpExternalAddress = false

    private(set) var usage: NetworkUsage = .empty

    private static let externalAddressURL = URL(string: "https://checkip.dyndns.org")!
    private static let externalLookupDelay: TimeInterval = 15

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func update(interval: TimeInterval) {
        let counters = interfaceCounters()

        if counters.address != localAddress {
            localAddress = counters.address
            externalAddress = ""
            scheduleExternalAddressLookup()
        }

        let seconds = max(interval, 0.001)
        let inbound = hasBaseline && counters.inBytes >= previousInBytes
            ? Double(counters.inBytes - previousInBytes) / seconds : 0
        let outbound = hasBaseline && counters.outBytes >= previousOutBytes
            ? Double(counters.outBytes - previousOutBytes) / seconds : 0

        previousInBytes = counters.inBytes
        previousOutBytes = counters.outBytes
        hasBaseline = true

        usage = NetworkUsage(
            address: externalAddress.isEmpty ? localAddress : externalAddress,
            inbound: Throughput(bytesPerSecond: inbound),
            outbound: Throughput(bytesPerSecond: outbound)
        )
    }

    private func interfaceCounters() -> (inBytes: UInt64, outBytes: UInt64, address: String) {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var active = ""
        var foundIPv4 = false

        guard getifaddrs(&addresses) == 0 else { return (0, 0, active) }
        defer { freeifaddrs(addresses) }

        var pointer = addresses
        while pointer != nil {
            defer { pointer = pointer?.pointee.ifa_next }
            guard let interface = pointer?.pointee, let address = interface.ifa_addr else { continue }

            let family = address.pointee.sa_family
            let flags = Int32(interface.ifa_flags)

            if family == UInt8(AF_LINK), let data = interface.ifa_data {
                let statistics = data.assumingMemoryBound(to: if_data.self).pointee
                totalIn += UInt64(statistics.ifi_ibytes)
                totalOut += UInt64(statistics.ifi_obytes)
            }

            guard (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING),
                  family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len),
                              &hostname, socklen_t(hostname.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }

            if family == UInt8(AF_INET) {
                active = String(cBuffer: hostname)
                foundIPv4 = true
            } else if !foundIPv4 {
                active = String(cBuffer: hostname)
            }
        }

        return (totalIn, totalOut, active)
    }

    private func scheduleExternalAddressLookup() {
        guard !isLookingUpExternalAddress else { return }
        isLookingUpExternalAddress = true

        queue.asyncAfter(deadline: .now() + Self.externalLookupDelay) { [weak self] in
            guard let self else { return }

            URLSession.shared.dataTask(with: Self.externalAddressURL) { [weak self] data, _, _ in
                guard let self else { return }

                let address = data.flatMap { Self.parseExternalAddress(from: $0) }
                self.queue.async {
                    self.isLookingUpExternalAddress = false
                    if let address { self.externalAddress = address }
                }
            }.resume()
        }
    }

    private static func parseExternalAddress(from data: Data) -> String? {
        guard let html = String(data: data, encoding: .utf8),
              let range = html.range(of: "Current IP Address: ") else { return nil }

        let address = html[range.upperBound...]
            .components(separatedBy: "<").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return address.isEmpty ? nil : address
    }
}

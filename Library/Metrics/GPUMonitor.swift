//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation
import IOKit

final class GPUMonitor {
    private var service: io_service_t = 0
    private var smoothing: [Double] = []
    private var smoothingSum: Double = 0
    private let smoothingWindow = 5

    private(set) var usage: Double = 0

    deinit {
        if service != 0 { IOObjectRelease(service) }
    }

    func update() {
        let current = currentUtilization() ?? 0

        smoothing.append(current)
        smoothingSum += current
        if smoothing.count > smoothingWindow {
            smoothingSum -= smoothing.removeFirst()
        }

        usage = roundedTenth(smoothingSum / Double(smoothing.count))
    }

    private func currentUtilization() -> Double? {
        if service == 0 { connect() }
        guard service != 0 else { return nil }

        guard let property = IORegistryEntryCreateCFProperty(service,
                                                             "PerformanceStatistics" as CFString,
                                                             kCFAllocatorDefault, 0),
              let performance = property.takeRetainedValue() as? [String: Any],
              let utilization = performance["Device Utilization %"] as? Int64 else {
            return nil
        }
        return Double(utilization)
    }

    private func connect() {
        guard let matching = IOServiceMatching("AGXAccelerator") else { return }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else { return }
        defer { IOObjectRelease(iterator) }

        service = IOIteratorNext(iterator)

        var extra = IOIteratorNext(iterator)
        while extra != 0 {
            IOObjectRelease(extra)
            extra = IOIteratorNext(iterator)
        }
    }
}

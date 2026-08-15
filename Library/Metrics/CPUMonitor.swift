//  Copyright © Takuto Nakamura, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation

final class CPUMonitor {
    private var previous = host_cpu_load_info()
    private var smoothing: [Double] = []
    private var smoothingSum: Double = 0
    private var detailed: [Double] = []

    private let smoothingWindow = 15
    private let detailCapacity = 900

    private(set) var usage: Double = 0
    var history: [Double] { detailed }

    func update() {
        let load = currentLoad()
        let user = Double(load.cpu_ticks.0 - previous.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1 - previous.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 - previous.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 - previous.cpu_ticks.3)
        previous = load

        let total = user + system + idle + nice
        guard total > 0 else { return }

        let current = roundedTenth(min(99.9, 100.0 * (system + user) / total))

        smoothing.append(current)
        smoothingSum += current
        if smoothing.count > smoothingWindow {
            smoothingSum -= smoothing.removeFirst()
        }

        detailed.append(current)
        if detailed.count > detailCapacity {
            detailed.removeFirst()
        }

        usage = roundedTenth(smoothingSum / Double(smoothing.count))
    }

    private func currentLoad() -> host_cpu_load_info {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return previous }
        return info
    }
}

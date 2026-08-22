//  Copyright © Takuto Nakamura, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation

final class MemoryMonitor {
    
    static let totalMemory: Double = {
        var size = mach_msg_type_number_t(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_basic_info_data_t()

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_info(machHost, HOST_BASIC_INFO, $0, &size)
            }
        }

        guard result == KERN_SUCCESS, info.max_mem > 0 else { return 1 }
        return Double(info.max_mem) / 1_073_741_824
    }()

    private var detailed: [Double] = []
    private let detailCapacity = 900

    private(set) var usage: MemoryUsage = .empty
    var history: [Double] { detailed }

    func update() {
        guard let statistics = vmStatistics() else { return }

        let unit = Double(sysconf(_SC_PAGESIZE)) / 1_073_741_824
        let total = Self.totalMemory

        let active = Double(statistics.active_count) * unit
        let speculative = Double(statistics.speculative_count) * unit
        let inactive = Double(statistics.inactive_count) * unit
        let wired = Double(statistics.wire_count) * unit
        let compressed = Double(statistics.compressor_page_count) * unit
        let purgeable = Double(statistics.purgeable_count) * unit
        let external = Double(statistics.external_page_count) * unit
        let used = active + inactive + speculative + wired + compressed - purgeable - external

        usage = MemoryUsage(
            used: roundedTenth(min(99.9, 100.0 * used / total)),
            pressure: roundedTenth(100.0 * (wired + compressed) / total),
            app: roundedTenth(100.0 * (used - wired - compressed) / total),
            compressed: roundedTenth(compressed),
            inactive: roundedTenth(100.0 * inactive / total),
            swap: swapUsage()
        )

        detailed.append(usage.used)
        if detailed.count > detailCapacity {
            detailed.removeFirst()
        }
    }

    private func vmStatistics() -> vm_statistics64? {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var info = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(machHost, HOST_VM_INFO64, $0, &size)
            }
        }

        return result == KERN_SUCCESS ? info : nil
    }

    private func swapUsage() -> Int {
        var mib = [CTL_VM, VM_SWAPUSAGE]
        var size = MemoryLayout<xsw_usage>.size
        var usage = xsw_usage()

        guard sysctl(&mib, 2, &usage, &size, nil, 0) == 0, usage.xsu_total > 0 else { return 0 }

        let percent = Double(usage.xsu_used) / Double(usage.xsu_total) * 100
        return percent.isFinite ? Int(percent) : 0
    }
}

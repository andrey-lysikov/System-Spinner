//  Copyright © Takuto Nakamura, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit
import Darwin

struct ProcessUsage: Identifiable {
    let pid: Int
    let name: String
    let cpu: Double
    let memory: Double
    let memoryText: String

    var id: Int { pid }

    var icon: NSImage {
        if let application = NSRunningApplication(processIdentifier: pid_t(pid)), let icon = application.icon {
            return icon
        }
        return NSWorkspace.shared.icon(forFile: "/bin/bash")
    }
}

final class ProcessMonitor {
    private var previousCPUTimes: [pid_t: UInt64] = [:]
    private var cached: [ProcessUsage] = []

    private static let pathInfoMaxSize: Int32 = 4096
    private static let taskInfoFlavor: Int32 = 4
    private static let bsdInfoFlavor: Int32 = 3

    func snapshot(systemCPUUsage: Double) -> [ProcessUsage] {
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return cached }

        var pids = [pid_t](repeating: 0, count: Int(pidCount))
        let listed = proc_listallpids(&pids, Int32(pidCount) * Int32(MemoryLayout<pid_t>.size))
        guard listed > 0 else { return cached }

        let totalMemory = MemoryMonitor.totalMemory
        var currentCPUTimes: [pid_t: UInt64] = [:]
        var candidates: [(pid: pid_t, name: String, cpuTime: Double, memory: Double, memoryText: String)] = []

        for index in 0 ..< Int(listed) {
            let pid = pids[index]
            guard pid > 0 else { continue }

            var task = proc_taskinfo()
            let taskSize = MemoryLayout<proc_taskinfo>.size
            guard proc_pidinfo(pid, Self.taskInfoFlavor, 0, &task, Int32(taskSize)) == Int32(taskSize) else { continue }
            guard let name = processName(for: pid), name != "WindowServer" else { continue }

            let cpuTime = task.pti_total_user + task.pti_total_system
            currentCPUTimes[pid] = cpuTime

            var delta: Double = 0
            if let previous = previousCPUTimes[pid], cpuTime > previous {
                delta = Double(cpuTime - previous) / 1_000_000_000.0
            }

            let residentBytes = Double(task.pti_resident_size)
            let memoryPercent = residentBytes / (totalMemory * 1024 * 1024 * 1024) * 100.0

            guard delta > 0 || memoryPercent > 0.1 else { continue }

            candidates.append((pid, name, delta, memoryPercent,
                               String(format: "%.1f MB", residentBytes / (1024 * 1024))))
        }

        previousCPUTimes = currentCPUTimes

        let totalCPUTime = candidates.reduce(0.0) { $0 + $1.cpuTime }
        var processes: [ProcessUsage] = []

        for candidate in candidates {
            let cpu = totalCPUTime > 0 ? candidate.cpuTime / totalCPUTime * systemCPUUsage : 0
            guard cpu > 0.05 || candidate.memory > 0.1 else { continue }

            processes.append(ProcessUsage(pid: Int(candidate.pid),
                                          name: candidate.name,
                                          cpu: roundedTenth(cpu),
                                          memory: roundedTenth(candidate.memory),
                                          memoryText: candidate.memoryText))
        }

        cached = processes.sorted { $0.cpu > $1.cpu }
        return cached
    }

    private func processName(for pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(Self.pathInfoMaxSize))
        if proc_pidpath(pid, &pathBuffer, UInt32(Self.pathInfoMaxSize)) > 0 {
            return (String(cBuffer: pathBuffer) as NSString).lastPathComponent
        }

        var bsd = proc_bsdinfo()
        let bsdSize = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(pid, Self.bsdInfoFlavor, 0, &bsd, Int32(bsdSize)) == Int32(bsdSize) else { return nil }

        return withUnsafeBytes(of: &bsd.pbi_comm) { bytes in
            guard let base = bytes.bindMemory(to: CChar.self).baseAddress else { return nil }
            return String(cString: base)
        }
    }
}

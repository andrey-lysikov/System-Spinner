//  Copyright © Takuto Nakamura, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Darwin
import Cocoa
import Foundation

// Константы для libproc API
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096
private let PROC_PIDTASKINFO: Int32 = 4
private let PROC_PIDTBSDINFO: Int32 = 3

class AKservice {
    private let loadInfoCount = UInt32(exactly: MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)!
    private let hostVmInfo64Count = UInt32(exactly: MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)!
    private let hostBasicInfoCount = UInt32(exactly: MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)!
    private var gpuService: io_service_t = 0
    private var loadPrevious = host_cpu_load_info()
    private let historyCount: Int = 15
    private let historyCountDetail: Int = 900
    private var loadCpuPreviousHist: [Double] = []
    private var loadGpuPreviousHist: [Double] = []
    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    public var loadCpuPreviousHistDetails: [Double] = []
    public var loadMemPreviousHistDetails: [Double] = []
    private var cachedLocalIP: String = ""
    private var cachedInternetIP: String = ""
    private var cpuHistSum: Double = 0.0
    private var gpuHistSum: Double = 0.0
    
    // Кэш для вычисления CPU usage процессов
    private var previousProcessCPUTimes: [pid_t: UInt64] = [:]
    private var lastProcessUpdateTime: Date = Date()
    private let processUpdateInterval: TimeInterval = 1.0 // обновляем раз в секунду
    private var cachedProcesses: [topProcess] = [] // Кэш последних вычисленных процессов
    
    public struct netPacketData {
        public var value: Double
        public var unit: String
    }
    
    public struct topProcess: Codable {
        public var pid: Int
        public var name: String
        public var cpu: Double
        public var mem: Double
        public var realmem: String
        
        public var icon: NSImage {
            get {
                if let app = NSRunningApplication(processIdentifier: pid_t(self.pid)), let icon = app.icon {
                    return icon
                }
                return NSWorkspace.shared.icon(forFile: "/bin/bash")
            }
        }
    }
    
    public var cpuPercentage: Double = 0.0
    public var gpuPercentage: Double = 0.0
    
    public var memPercentage: Double = 0.0
    public var memPressure: Double = 0.0
    public var memApp: Double = 0.0
    public var memCompressed: Double = 0.0
    public var memInactive: Double = 0.0
    public var memSwap: Int = 0
    public var netIp: String = localizedString("no ip found")
    public var netIn = netPacketData(value: 0.0, unit: localizedString("KB/s"))
    public var netOut = netPacketData(value: 0.0, unit: localizedString("KB/s"))
    
    private func round(In: Double) -> Double {
        return Double(ceil(In * 10) / 10.0)
    }
    
    private func hostCPULoadInfo() -> host_cpu_load_info {
         var info = host_cpu_load_info_data_t()
         var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
         
         let kerr: kern_return_t = withUnsafeMutablePointer(to: &info, {
             host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0.withMemoryRebound(to: integer_t.self, capacity: 1, { $0 }), &count)
         })
         
         guard kerr == KERN_SUCCESS else {
             return host_cpu_load_info()
         }
         
         return info
     }
    
    public func getTopProcess() -> [topProcess] {
        var processes: [topProcess] = []
        let now = Date()
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return cachedProcesses }
        
        var pids = [pid_t](repeating: 0, count: Int(pidCount))
        let bufferSize = Int32(pidCount) * Int32(MemoryLayout<pid_t>.size)
        let actualCount = proc_listallpids(&pids, bufferSize)
        guard actualCount > 0 else { return cachedProcesses }
        
        let totalPids = Int(actualCount)
        let maxMemoryGB = maxMemory
        
        var currentProcessCPUTimes: [pid_t: UInt64] = [:]
        var processesRaw: [(pid: pid_t, name: String, cpuTime: Double, mem: Double, memString: String)] = []
 
        for i in 0..<totalPids {
            let pid = pids[i]
            guard pid > 0 else { continue }
            
            var taskInfo = proc_taskinfo()
            let taskInfoSize = MemoryLayout<proc_taskinfo>.size
            
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(taskInfoSize))
            guard result == Int32(taskInfoSize) else { continue }
            
            // Получаем имя процесса
            var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
            
            var processName: String
            if pathLength > 0 {
                let fullPath = String(cString: pathBuffer)
                processName = (fullPath as NSString).lastPathComponent
            } else {
                var bsdInfo = proc_bsdinfo()
                let bsdInfoSize = MemoryLayout<proc_bsdinfo>.size
                let bsdResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(bsdInfoSize))
                
                if bsdResult == Int32(bsdInfoSize) {
                    processName = withUnsafeBytes(of: &bsdInfo.pbi_comm) { bytes in
                        let buffer = bytes.bindMemory(to: CChar.self)
                        return String(cString: buffer.baseAddress!)
                    }
                } else {
                    continue
                }
            }
            
            guard processName != "WindowServer" else { continue }
            let currentTotalTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            currentProcessCPUTimes[pid] = currentTotalTime
            
            var cpuTimeDelta: Double = 0.0
            if let previousTime = previousProcessCPUTimes[pid], currentTotalTime > previousTime {
                cpuTimeDelta = Double(currentTotalTime - previousTime) / 1_000_000_000.0 // Конвертируем в секунды
            }
            
            // Memory usage
            let memoryBytes = taskInfo.pti_resident_size
            let memoryMB = Double(memoryBytes) / (1024 * 1024)
            let memoryPercent = (Double(memoryBytes) / (maxMemoryGB * 1024 * 1024 * 1024)) * 100.0
            let memoryString = String(format: "%.1f MB", memoryMB)
            
            if cpuTimeDelta > 0.0 || memoryPercent > 0.1 {
                processesRaw.append((
                    pid: pid,
                    name: processName,
                    cpuTime: cpuTimeDelta,
                    mem: memoryPercent,
                    memString: memoryString
                ))
            }
        }
        
        previousProcessCPUTimes = currentProcessCPUTimes
        lastProcessUpdateTime = now
        
        let totalProcessCPUTime = processesRaw.reduce(0.0) { $0 + $1.cpuTime }
        let systemCPUPercent = cpuPercentage
        
        for processRaw in processesRaw {
            let cpuUsagePercent: Double
            
            if totalProcessCPUTime > 0 {
                let processShare = processRaw.cpuTime / totalProcessCPUTime
                cpuUsagePercent = processShare * systemCPUPercent
            } else {
                cpuUsagePercent = 0.0
            }
            if cpuUsagePercent > 0.05 || processRaw.mem > 0.1 {
                processes.append(topProcess(
                    pid: Int(processRaw.pid),
                    name: processRaw.name,
                    cpu: round(In: cpuUsagePercent),
                    mem: round(In: processRaw.mem),
                    realmem: processRaw.memString
                ))
            }
        }
        
        let sortedProcesses = processes.sorted { $0.cpu > $1.cpu }
        cachedProcesses = sortedProcesses
        
        return sortedProcesses
    }
    
    private func setupGPUService() {
          guard let matchingDict = IOServiceMatching("AGXAccelerator") else { return }
          
          var iterator: io_iterator_t = 0
          let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
          
          guard result == kIOReturnSuccess, iterator != 0 else { return }
          defer { IOObjectRelease(iterator) }
          
          let service = IOIteratorNext(iterator)
          if service != 0 {
              self.gpuService = service
          }
          
          var unusedService = IOIteratorNext(iterator)
          while unusedService != 0 {
              IOObjectRelease(unusedService)
              unusedService = IOIteratorNext(iterator)
          }
      }

    public func getGPUUsage() -> Double? {
        if gpuService == 0 {
            setupGPUService()
        }
        var entryProperties: Unmanaged<CFMutableDictionary>?
        let registryResult = IORegistryEntryCreateCFProperties(gpuService, &entryProperties, kCFAllocatorDefault, 0)
            if registryResult == KERN_SUCCESS, let properties = entryProperties?.takeRetainedValue() {
               if let perfStats = CFDictionaryGetValue(properties, Unmanaged.passUnretained("PerformanceStatistics" as CFString).toOpaque()) {
                   let statsDict = Unmanaged<CFDictionary>.fromOpaque(perfStats).takeUnretainedValue() as NSDictionary
                   if let utilization = statsDict["Device Utilization %"] as? Int64 {
                       return Double(utilization)
                   }
            }
        }
        return nil
    }
    
    private var vmStatistics64: vm_statistics64 {
          var size: mach_msg_type_number_t = hostVmInfo64Count
          let hostInfo = vm_statistics64_t.allocate(capacity: 1)
          let _ = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { (pointer) -> kern_return_t in
              return host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &size)
          }
          let data = hostInfo.move()
          hostInfo.deallocate()
          return data
    }
    
    private var maxMemory: Double {
          var size: mach_msg_type_number_t = hostBasicInfoCount
          let hostInfo = host_basic_info_t.allocate(capacity: 1)
          let _ = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int()) { (pointer) -> kern_return_t in
              return host_info(mach_host_self(), HOST_BASIC_INFO, pointer, &size)
          }
          let data = hostInfo.move()
          hostInfo.deallocate()
          return Double(data.max_mem) / 1073741824
    }
    
    func getSystemSwapUsage() -> Int {
        var mib = [CTL_VM, VM_SWAPUSAGE]
        var size = MemoryLayout<xsw_usage>.size
        var usage = xsw_usage()
        
        guard sysctl(&mib, 2, &usage, &size, nil, 0) == 0, usage.xsu_total > 0 else { return 0 }
        
        let swSize = (Double(usage.xsu_used) / Double(usage.xsu_total) * 100)
        
        return swSize.isNaN || swSize.isInfinite ? 0 : Int(swSize)
    }
    
    private func convert(byte: Double) -> netPacketData {
        let KB: Double = 1024
        let MB: Double = pow(KB, 2)
        let GB: Double = pow(KB, 3)
        let TB: Double = pow(KB, 4)
        if TB <= byte {
            return netPacketData(value: round(In: byte / TB), unit: localizedString("TB/s"))
        } else if GB <= byte {
            return netPacketData(value: round(In: byte / GB), unit: localizedString("GB/s"))
        } else if MB <= byte {
            return netPacketData(value: round(In: byte / MB), unit: localizedString("MB/s"))
        } else {
            return netPacketData(value: round(In: byte / KB), unit: localizedString("KB/s"))
        }
    }
    
    private func getNetworkInterfaceBytesAndIP() -> (inBytes: UInt64, outBytes: UInt64, activeIP: String) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var activeIPAddress: String = localizedString("no ip found")
        
        guard getifaddrs(&ifaddr) == 0 else {
            return (0, 0, activeIPAddress)
        }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let interface = ptr?.pointee else { continue }
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            let flags = Int32(interface.ifa_flags)
            
            if addrFamily == UInt8(AF_LINK) {
                if let dataPtr = interface.ifa_data {
                    let stats = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(stats.ifi_ibytes)
                    totalOut += UInt64(stats.ifi_obytes)
                }
            }
            
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    let result = getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    
                    if result == 0 {
                        let ip = String(cString: hostname)
                        if addrFamily == UInt8(AF_INET) {
                            activeIPAddress = ip
                        } else if activeIPAddress == localizedString("no ip found") {
                            activeIPAddress = ip
                        }
                    }
                }
            }
        }
    
        if cachedLocalIP != activeIPAddress {
            let startAfter: DispatchTime = .now() + 15
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: startAfter) { [weak self] in
                guard let self = self else { return }
                URLSession.shared.dataTask(with: URL(string: "https://checkip.dyndns.org")!) { (data, res, err) in
                    guard let data = data else {
                        return
                    }

                    if let html = String(data: data, encoding: .utf8) {
                        if let range = html.range(of: "Current IP Address: ") {
                            let potentialIP = String(html[range.upperBound...])
                            let ip = potentialIP.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if !ip.isEmpty {
                                self.cachedInternetIP = ip
                            }
                        }
                    }
                
                }.resume()
            }
            cachedLocalIP = activeIPAddress
            cachedInternetIP = ""
        }
    
        if cachedInternetIP.isEmpty {
            return (totalIn, totalOut, cachedLocalIP)
        } else {
            return (totalIn, totalOut, cachedInternetIP)
        }
    }
    
    public func update() {
        let load = hostCPULoadInfo()
        let cpuUser = Double(load.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
        let cpuSystem = Double(load.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
        let cpuIdle = Double(load.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
        let cpuNiceD =  Double(load.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
        
        let totalTicks  = cpuUser + cpuSystem + cpuIdle + cpuNiceD
        
        let cpuLast = round(In: min(99.9, ((100.0 * cpuSystem / totalTicks) + (100.0 * cpuUser / totalTicks))))
        
        loadCpuPreviousHist.append(cpuLast)
        loadCpuPreviousHistDetails.append(cpuLast)
        cpuHistSum += cpuLast
        
        if loadCpuPreviousHist.count > historyCount {
            let removed = loadCpuPreviousHist.removeFirst()
            cpuHistSum -= removed
        }
        
        if loadCpuPreviousHistDetails.count > historyCountDetail {
            loadCpuPreviousHistDetails.removeFirst()
        }
        
        cpuPercentage = round(In: cpuHistSum / Double(loadCpuPreviousHist.count))
        
        loadPrevious  = load
        
        let gpuLast = getGPUUsage() ?? 0.0
        loadGpuPreviousHist.append(gpuLast)
        gpuHistSum += gpuLast
        if loadGpuPreviousHist.count > historyCount {
            let removed = loadGpuPreviousHist.removeFirst()
            gpuHistSum -= removed
        }
        gpuPercentage = round(In: gpuHistSum / Double(loadGpuPreviousHist.count))
        
        // Update MEM Data
        let memLoad = vmStatistics64
        let cachedMaxMemory = maxMemory
        let unit        = Double(vm_kernel_page_size) / 1073741824
        
        let active      = Double(memLoad.active_count) * unit
        let speculative = Double(memLoad.speculative_count) * unit
        let inactive    = Double(memLoad.inactive_count) * unit
        let wired       = Double(memLoad.wire_count) * unit
        let compressed  = Double(memLoad.compressor_page_count) * unit
        let purgeable   = Double(memLoad.purgeable_count) * unit
        let external    = Double(memLoad.external_page_count) * unit
        let using       = active + inactive + speculative + wired + compressed - purgeable - external
        
        memPercentage = round(In: min(99.9, (100.0 * using / cachedMaxMemory)))
        memPressure   = round(In: 100.0 * (wired + compressed) / cachedMaxMemory)
        memApp        = round(In: 100.0 * (using - wired - compressed) / cachedMaxMemory)
        memCompressed = round(In: compressed)
        memInactive = round(In: 100.0 * (inactive) / cachedMaxMemory)
        
        loadMemPreviousHistDetails.append(memPercentage)
        if loadMemPreviousHistDetails.count > historyCountDetail {
            loadMemPreviousHistDetails.removeFirst()
        }
        
        memSwap = getSystemSwapUsage()
        
        // Update NET Data
        let net = getNetworkInterfaceBytesAndIP()
        netIp = net.activeIP
        netIn = convert(byte: Double(net.inBytes >= lastInBytes ? net.inBytes - lastInBytes : 0))
        netOut = convert(byte: Double(net.outBytes >= lastOutBytes ? net.outBytes - lastOutBytes : 0))
        lastInBytes = net.inBytes
        lastOutBytes = net.outBytes
    }
    
    init() {
        update()
    }
    
}

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        sorted { a, b in
            a[keyPath: keyPath] > b[keyPath: keyPath]
        }
    }
}

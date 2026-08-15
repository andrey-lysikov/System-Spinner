//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation

struct Throughput {
    let bytesPerSecond: Double

    static let zero = Throughput(bytesPerSecond: 0)

    var value: Double { scaled.value }
    var unit: String { scaled.unit }

    private var scaled: (value: Double, unit: String) {
        let kilobyte = 1024.0
        let megabyte = pow(kilobyte, 2)
        let gigabyte = pow(kilobyte, 3)
        let terabyte = pow(kilobyte, 4)

        switch bytesPerSecond {
        case terabyte...:
            return (bytesPerSecond / terabyte, localizedString("TB/s"))
        case gigabyte ..< terabyte:
            return (bytesPerSecond / gigabyte, localizedString("GB/s"))
        case megabyte ..< gigabyte:
            return (bytesPerSecond / megabyte, localizedString("MB/s"))
        default:
            return (bytesPerSecond / kilobyte, localizedString("KB/s"))
        }
    }
}

struct MemoryUsage {
    var used: Double = 0
    var pressure: Double = 0
    var app: Double = 0
    var compressed: Double = 0
    var inactive: Double = 0
    var swap: Int = 0

    static let empty = MemoryUsage()
}

struct NetworkUsage {
    var address: String = ""
    var inbound: Throughput = .zero
    var outbound: Throughput = .zero

    static let empty = NetworkUsage()
}

/// Потребители получают копию и не имеют доступа к состоянию мониторов.
struct MetricsSnapshot {
    var cpuUsage: Double = 0
    var gpuUsage: Double = 0
    var memory: MemoryUsage = .empty
    var network: NetworkUsage = .empty
    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []
    var sensors: SensorsSnapshot = .unavailable

    static let empty = MetricsSnapshot()
}

func roundedTenth(_ value: Double) -> Double {
    (value * 10).rounded(.up) / 10
}

final class MetricsService {
    typealias Observer = (MetricsSnapshot) -> Void

    static let shared = MetricsService()

    private let queue = DispatchQueue(label: "com.system-spinner.metrics", qos: .utility)
    private let lock = NSLock()

    private let cpu = CPUMonitor()
    private let gpu = GPUMonitor()
    private let memory = MemoryMonitor()
    private let processes = ProcessMonitor()
    private lazy var network = NetworkMonitor(queue: queue)
    private let sensors = SensorService()

    private var timer: DispatchSourceTimer?
    private var interval: TimeInterval = 1
    private var readsDetailedMetrics = false
    private var skipsGPUSample = false
    private var observers: [UUID: Observer] = [:]
    private var storage: MetricsSnapshot = .empty

    private init() {}

    var snapshot: MetricsSnapshot {
        lock.withLock { storage }
    }

    var sensorsAvailable: Bool { sensors.isAvailable }
    var hasFans: Bool { sensors.hasFans }

    func start(interval: TimeInterval) {
        queue.async { [self] in
            self.interval = interval
            timer?.cancel()

            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(100))
            source.setEventHandler { [weak self] in self?.tick() }
            timer = source
            source.resume()
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
        }
    }

    @discardableResult
    func addObserver(_ observer: @escaping Observer) -> UUID {
        let token = UUID()
        lock.withLock { observers[token] = observer }
        return token
    }

    func removeObserver(_ token: UUID) {
        lock.withLock { _ = observers.removeValue(forKey: token) }
    }

    func setDetailedMetricsEnabled(_ enabled: Bool) {
        queue.async { [self] in
            readsDetailedMetrics = enabled
            gpu.reset()
            skipsGPUSample = enabled
            
            guard enabled, sensors.isAvailable else { return }
            var updated = lock.withLock { storage }
            updated.sensors = sensors.read()
            publish(updated)
        }
    }

    func topProcesses(completion: @escaping ([ProcessUsage]) -> Void) {
        queue.async { [self] in
            let usage = processes.snapshot(systemCPUUsage: cpu.usage)
            DispatchQueue.main.async { completion(usage) }
        }
    }

    private func tick() {
        cpu.update()
        memory.update()
        network.update(interval: interval)

        if readsDetailedMetrics {
            if skipsGPUSample {
                skipsGPUSample = false
            } else {
                gpu.update()
            }
        }

        var updated = MetricsSnapshot(
            cpuUsage: cpu.usage,
            gpuUsage: gpu.usage,
            memory: memory.usage,
            network: network.usage,
            cpuHistory: cpu.history,
            memoryHistory: memory.history
        )
        updated.sensors = readsDetailedMetrics && sensors.isAvailable ? sensors.read() : .unavailable

        publish(updated)
    }

    private func publish(_ snapshot: MetricsSnapshot) {
        let handlers: [Observer] = lock.withLock {
            storage = snapshot
            return Array(observers.values)
        }

        guard !handlers.isEmpty else { return }
        DispatchQueue.main.async {
            handlers.forEach { $0(snapshot) }
        }
    }
}

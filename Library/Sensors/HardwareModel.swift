//  Copyright © Serhiy Mytrovtsiy, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0
//  Таблицы датчиков из https://github.com/exelban/stats

import Foundation

enum ChipFamily: String, CaseIterable {
    case m1 = "M1"
    case m2 = "M2"
    case m3 = "M3"
    case m4 = "M4"
    case m5 = "M5"
}

enum SMCKeys {
    static let systemPower = "PSTR"
    static let batteryPower = "PPBR"
    static let adapterPower = "PDTR"

    static func fanSpeed(count: Int) -> [String] {
        (0 ..< count).map { "F\($0)Ac" }
    }

    static func cpuTemperature(for chip: ChipFamily) -> [String] {
        cpuTemperatureKeys[chip] ?? cpuTemperatureKeys[.m1] ?? []
    }

    private static let cpuTemperatureKeys: [ChipFamily: [String]] = [
        .m1: ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"],
        .m2: ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"],
        .m3: ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E",
              "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"],
        .m4: ["Te05", "Te0S", "Te09", "Te0H", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"],
        .m5: ["Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X",
              "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"],
    ]

}

struct HardwareModel {
    let chip: ChipFamily

    static let current = HardwareModel()

    private init() {
        chip = Self.chipFamily(from: Self.sysctlString("machdep.cpu.brand_string"))
    }

    static func chipFamily(from brand: String) -> ChipFamily {
        let uppercased = brand.uppercased()
        
        for family in ChipFamily.allCases.reversed()
        where uppercased.range(of: "\\b\(family.rawValue)\\b", options: .regularExpression) != nil {
            return family
        }
        return .m1
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }

        return String(cBuffer: buffer)
    }
}

struct SensorsSnapshot {
    var cpuTemperature: Double = 0
    var fanSpeeds: [Int] = []
    var systemPower: Int = 0
    var batteryPower: Int = 0
    var adapterPower: Int = 0

    static let unavailable = SensorsSnapshot()
}

final class SensorService {
    private let smc: SMCService?
    private let temperatureKeys: [String]
    private let fanKeys: [String]

    let isAvailable: Bool
    let hasFans: Bool

    init() {
        let connection = try? SMCService()
        smc = connection

        guard let connection else {
            temperatureKeys = []
            fanKeys = []
            isAvailable = false
            hasFans = false
            return
        }

        temperatureKeys = connection.readableKeys(among: SMCKeys.cpuTemperature(for: HardwareModel.current.chip))
        let fanCount = connection.fanCount
        fanKeys = SMCKeys.fanSpeed(count: fanCount)
        isAvailable = !temperatureKeys.isEmpty
        hasFans = fanCount > 0
    }

    func read() -> SensorsSnapshot {
        guard let smc else { return .unavailable }

        var snapshot = SensorsSnapshot()
        snapshot.cpuTemperature = temperatureKeys.reduce(0) { max($0, smc.optionalValue(forKey: $1) ?? 0) }
        snapshot.fanSpeeds = fanKeys.map { Int(smc.optionalValue(forKey: $0) ?? 0) }
        snapshot.systemPower = Int((smc.optionalValue(forKey: SMCKeys.systemPower) ?? 0).rounded())
        snapshot.batteryPower = Int((smc.optionalValue(forKey: SMCKeys.batteryPower) ?? 0).rounded())
        snapshot.adapterPower = Int((smc.optionalValue(forKey: SMCKeys.adapterPower) ?? 0).rounded())
        return snapshot
    }
}

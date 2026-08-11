//  Copyright © Serhiy Mytrovtsiy, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0
// imported from https://raw.githubusercontent.com/exelban/stats/refs/heads/master/Modules/Sensors/values.swift

internal enum SensorType: String {
    case CPU = "CPU"
    case GPU = "GPU"
    case FAN = "FAN"
    case FAN_SPEED = "FAN SPEED"
    case POWER = "POWER"
    case BATTERY = "BATTERY"
    case ADAPTER = "ADAPTER"
}

internal enum CPU_MODEL: String {
    case M1 = "M1"
    case M2 = "M2"
    case M3 = "M3"
    case M4 = "M4"
    case M5 = "M5"
}

internal struct SensorsList_s {
    var key: String
    var value: String
}

internal struct FanlessConfiguration {
    static let models: [String] = [
        "MACBOOK AIR",
        "MAC MINI M1",
        "IMAC 24",
    ]
    
    static func isFanless(modelName: String) -> Bool {
        let upperModel = modelName.uppercased()
        return models.contains { upperModel.contains($0) }
    }
}

private let defaultSensors: [SensorType: [SensorsList_s]] = [
    .FAN: [
        SensorsList_s(key: "TaLP", value: "Airflow left"),
        SensorsList_s(key: "TaRF", value: "Airflow right"),
    ],
    .FAN_SPEED: [
        SensorsList_s(key: "F0Ac", value: "Fan 0"),
        SensorsList_s(key: "F1Ac", value: "Fan 1")
    ],
    .POWER: [
        SensorsList_s(key: "PSTR", value: "System total"),
    ],
    .BATTERY: [
        SensorsList_s(key: "PPBR", value: "Battery rail"),
    ],
    .ADAPTER: [
        SensorsList_s(key: "PDTR", value: "DC In total"),
    ]
]

internal let SensorsList: [CPU_MODEL: [SensorType: [SensorsList_s]]] = [
    .M1: [
        .CPU: [
            SensorsList_s(key: "Tp09", value: "CPU efficiency core 1"),
            SensorsList_s(key: "Tp0T", value: "CPU efficiency core 2"),
            SensorsList_s(key: "Tp01", value: "CPU performance core 1"),
            SensorsList_s(key: "Tp05", value: "CPU performance core 2"),
            SensorsList_s(key: "Tp0D", value: "CPU performance core 3"),
            SensorsList_s(key: "Tp0H", value: "CPU performance core 4"),
            SensorsList_s(key: "Tp0L", value: "CPU performance core 5"),
            SensorsList_s(key: "Tp0P", value: "CPU performance core 6"),
            SensorsList_s(key: "Tp0X", value: "CPU performance core 7"),
            SensorsList_s(key: "Tp0b", value: "CPU performance core 8"),
        ],
        .GPU: [
            SensorsList_s(key: "Tg05", value: "GPU 1"),
            SensorsList_s(key: "Tg0D", value: "GPU 2"),
            SensorsList_s(key: "Tg0L", value: "GPU 3"),
            SensorsList_s(key: "Tg0T", value: "GPU 4"),
        ],
    ],
    .M2: [
        .CPU: [
            SensorsList_s(key: "Tp1h", value: "CPU efficiency core 1"),
            SensorsList_s(key: "Tp1t", value: "CPU efficiency core 2"),
            SensorsList_s(key: "Tp1p", value: "CPU efficiency core 3"),
            SensorsList_s(key: "Tp1l", value: "CPU efficiency core 4"),
            SensorsList_s(key: "Tp01", value: "CPU performance core 1"),
            SensorsList_s(key: "Tp05", value: "CPU performance core 2"),
            SensorsList_s(key: "Tp09", value: "CPU performance core 3"),
            SensorsList_s(key: "Tp0D", value: "CPU performance core 4"),
            SensorsList_s(key: "Tp0X", value: "CPU performance core 5"),
            SensorsList_s(key: "Tp0b", value: "CPU performance core 6"),
            SensorsList_s(key: "Tp0f", value: "CPU performance core 7"),
            SensorsList_s(key: "Tp0j", value: "CPU performance core 8"),
        ],
        .GPU: [
            SensorsList_s(key: "Tg0f", value: "GPU 1"),
            SensorsList_s(key: "Tg0j", value: "GPU 2"),
        ],
    ],
    .M3: [
        .CPU: [
            SensorsList_s(key: "Te05", value: "CPU efficiency core 1"),
            SensorsList_s(key: "Te0L", value: "CPU efficiency core 2"),
            SensorsList_s(key: "Te0P", value: "CPU efficiency core 3"),
            SensorsList_s(key: "Te0S", value: "CPU efficiency core 4"),
            SensorsList_s(key: "Tf04", value: "CPU performance core 1"),
            SensorsList_s(key: "Tf09", value: "CPU performance core 2"),
            SensorsList_s(key: "Tf0A", value: "CPU performance core 3"),
            SensorsList_s(key: "Tf0B", value: "CPU performance core 4"),
            SensorsList_s(key: "Tf0D", value: "CPU performance core 5"),
            SensorsList_s(key: "Tf0E", value: "CPU performance core 6"),
            SensorsList_s(key: "Tf44", value: "CPU performance core 7"),
            SensorsList_s(key: "Tf49", value: "CPU performance core 8"),
            SensorsList_s(key: "Tf4A", value: "CPU performance core 9"),
            SensorsList_s(key: "Tf4B", value: "CPU performance core 10"),
            SensorsList_s(key: "Tf4D", value: "CPU performance core 11"),
            SensorsList_s(key: "Tf4E", value: "CPU performance core 12"),
        ],
        .GPU: [
            SensorsList_s(key: "Tf14", value: "GPU 1"),
            SensorsList_s(key: "Tf18", value: "GPU 2"),
            SensorsList_s(key: "Tf19", value: "GPU 3"),
            SensorsList_s(key: "Tf1A", value: "GPU 4"),
            SensorsList_s(key: "Tf24", value: "GPU 5"),
            SensorsList_s(key: "Tf28", value: "GPU 6"),
            SensorsList_s(key: "Tf29", value: "GPU 7"),
            SensorsList_s(key: "Tf2A", value: "GPU 8"),
        ],
    ],
    .M4: [
        .CPU: [
            SensorsList_s(key: "Te05", value: "CPU efficiency core 1"),
            SensorsList_s(key: "Te0S", value: "CPU efficiency core 2"),
            SensorsList_s(key: "Te09", value: "CPU efficiency core 3"),
            SensorsList_s(key: "Te0H", value: "CPU efficiency core 4"),
            SensorsList_s(key: "Tp01", value: "CPU performance core 1"),
            SensorsList_s(key: "Tp05", value: "CPU performance core 2"),
            SensorsList_s(key: "Tp09", value: "CPU performance core 3"),
            SensorsList_s(key: "Tp0D", value: "CPU performance core 4"),
            SensorsList_s(key: "Tp0V", value: "CPU performance core 5"),
            SensorsList_s(key: "Tp0Y", value: "CPU performance core 6"),
            SensorsList_s(key: "Tp0b", value: "CPU performance core 7"),
            SensorsList_s(key: "Tp0e", value: "CPU performance core 8"),
        ],
        .GPU: [
            SensorsList_s(key: "Tg0G", value: "GPU 1"),
            SensorsList_s(key: "Tg0H", value: "GPU 2"),
            SensorsList_s(key: "Tg1U", value: "GPU 3"),
            SensorsList_s(key: "Tg1k", value: "GPU 4"),
            SensorsList_s(key: "Tg0K", value: "GPU 5"),
            SensorsList_s(key: "Tg0L", value: "GPU 6"),
            SensorsList_s(key: "Tg0d", value: "GPU 7"),
            SensorsList_s(key: "Tg0e", value: "GPU 8"),
            SensorsList_s(key: "Tg0j", value: "GPU 9"),
            SensorsList_s(key: "Tg0k", value: "GPU 10"),
        ],
    ],
    .M5: [
        .CPU: [
            SensorsList_s(key: "Tp00", value: "CPU performance core 1"),
            SensorsList_s(key: "Tp04", value: "CPU performance core 2"),
            SensorsList_s(key: "Tp08", value: "CPU performance core 3"),
            SensorsList_s(key: "Tp0C", value: "CPU performance core 4"),
            SensorsList_s(key: "Tp0G", value: "CPU performance core 5"),
            SensorsList_s(key: "Tp0K", value: "CPU performance core 6"),
            SensorsList_s(key: "Tp0O", value: "CPU performance core 7"),
            SensorsList_s(key: "Tp0R", value: "CPU performance core 8"),
            SensorsList_s(key: "Tp0U", value: "CPU performance core 9"),
            SensorsList_s(key: "Tp0X", value: "CPU performance core 10"),
            SensorsList_s(key: "Tp0a", value: "CPU performance core 11"),
            SensorsList_s(key: "Tp0d", value: "CPU performance core 12"),
            SensorsList_s(key: "Tp0g", value: "CPU performance core 13"),
            SensorsList_s(key: "Tp0j", value: "CPU performance core 14"),
            SensorsList_s(key: "Tp0m", value: "CPU performance core 15"),
            SensorsList_s(key: "Tp0p", value: "CPU performance core 16"),
            SensorsList_s(key: "Tp0u", value: "CPU efficiency core 1"),
            SensorsList_s(key: "Tp0y", value: "CPU efficiency core 2"),
        ],
        .GPU: [
            SensorsList_s(key: "Tg0U", value: "GPU 1"),
            SensorsList_s(key: "Tg0X", value: "GPU 2"),
            SensorsList_s(key: "Tg0d", value: "GPU 3"),
            SensorsList_s(key: "Tg0g", value: "GPU 4"),
            SensorsList_s(key: "Tg0j", value: "GPU 5"),
            SensorsList_s(key: "Tg1Y", value: "GPU 6"),
            SensorsList_s(key: "Tg1c", value: "GPU 7"),
            SensorsList_s(key: "Tg1g", value: "GPU 8"),
        ],
    ],
]

class IOServiceData {
    private var con: io_connect_t = 0
    private var cpuTempKeys: [String] = []
    private var gpuTempKeys: [String] = []
    private var fanTempKeys: [String] = []
    private var fanSpeedKeys:  [String] = []
    private var systemPowerKeys: [String] = []
    private var systemAdapterKeys: [String] = []
    private var systemBatteryKeys: [String] = []
    private let KERNEL_INDEX_SMC: UInt32 = 2
    private let SMC_CMD_READ_BYTES: UInt8 = 5
    private let SMC_CMD_READ_KEYINFO: UInt8 = 9
    public var isFanlessModel: Bool = false
    public var presentSMC: Bool = true
    
    // data for translate
    public var cpuTemp: Double = 0.0
    public var gpuTemp: Double = 0.0
    public var fanTemp: Double = 0.0
    public var fanSpeed: [Int] = []
    public var systemPower: Int = 0
    public var systemAdapter: Int = 0
    public var systemBattery: Int = 0
    
    private struct AppleSMCVers { // 6 bytes
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }
    
    private struct AppleSMCLimit { // 16 bytes
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpu: UInt32 = 0
        var gpu: UInt32 = 0
        var mem: UInt32 = 0
    }
    
    private struct AppleSMCInfo { // 9+3=12 bytes
        var size: UInt32 = 0
        var type = AppleSMC4Chars()
        var attribute: UInt8 = 0
        var unused1: UInt8 = 0
        var unused2: UInt8 = 0
        var unused3: UInt8 = 0
    }
    
    private struct AppleSMCBytes { // 32 bytes
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }
    enum MyError: Error {
        case iokit(kern_return_t)
        case string(String)
    }
    
    private struct AppleSMC4Chars {  // 4 bytes
        var chars: (UInt8, UInt8, UInt8, UInt8) = (0,0,0,0)
        init() {
        }
        init(chars: (UInt8, UInt8, UInt8, UInt8)) {
            self.chars = chars
        }
        init(_ string: String) throws {
            // This looks silly but I don't know a better solution
            guard string.lengthOfBytes(using: .utf8) == 4 else { throw MyError.string("Sensor name \(string) must be 4 characters long")}
            chars.0 = string.utf8.reversed()[0]
            chars.1 = string.utf8.reversed()[1]
            chars.2 = string.utf8.reversed()[2]
            chars.3 = string.utf8.reversed()[3]
        }
    }
    
    private struct AppleSMCKey {
        var key = AppleSMC4Chars()
        var vers = AppleSMCVers()
        var limit = AppleSMCLimit()
        var info = AppleSMCInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes = AppleSMCBytes()
    }
    
    private func process(path: String, arguments: [String]) -> String? {
        let task = Process()
        task.launchPath = path
        task.arguments = arguments
        
        let outputPipe = Pipe()
        defer {
            outputPipe.fileHandleForReading.closeFile()
        }
        task.standardOutput = outputPipe
        
        task.launch()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        
        task.waitUntilExit()
        
        if output.isEmpty {
            return nil
        }
        
        return output
    }
    
    private func getMacModel() -> String? {
        guard let res = process(path: "/usr/sbin/system_profiler", arguments: ["SPHardwareDataType", "-json"]) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(res.utf8), options: []) as? [String: Any],
               let obj = json["SPHardwareDataType"] as? [[String: Any]], !obj.isEmpty, let val = obj.first,
               let name = val["machine_name"] as? String {
                return name
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func getCpuModel() -> CPU_MODEL {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brandString = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brandString, &size, nil, 0)
        let cpuBrand = String(cString: brandString).uppercased()
        
        isFanlessModel = FanlessConfiguration.isFanless(modelName: getMacModel() ?? "")

        // Check for Apple Silicon chips in reverse order (newest first)
        if cpuBrand.range(of: "\\bM5\\b", options: .regularExpression) != nil ||
           cpuBrand.contains("APPLE M5") {
            return .M5
        } else if cpuBrand.range(of: "\\bM4\\b", options: .regularExpression) != nil ||
                  cpuBrand.contains("APPLE M4") {
            return .M4
        } else if cpuBrand.range(of: "\\bM3\\b", options: .regularExpression) != nil ||
                  cpuBrand.contains("APPLE M3") {
            return .M3
        } else if cpuBrand.range(of: "\\bM2\\b", options: .regularExpression) != nil ||
                  cpuBrand.contains("APPLE M2") {
            return .M2
        } else if cpuBrand.range(of: "\\bM1\\b", options: .regularExpression) != nil ||
                  cpuBrand.contains("APPLE M1") {
            // Some M1 fanless models don't have accessible SMC
            if isFanlessModel {
                presentSMC = false
            }
            return .M1
        }
        
        return .M1
    }
    
    init() {
        let mainport: mach_port_t = 0
        let serviceDir = IOServiceMatching("AppleSMC")
        let service = IOServiceGetMatchingService(mainport, serviceDir)
        IOServiceOpen(service, mach_task_self_ , 0, &con)
        IOObjectRelease(service)
        
        let cpuModel = getCpuModel()
        
        // Fallback на M1, если модель не найдена в словаре
        let modelSensors = SensorsList[cpuModel] ?? SensorsList[.M1]!
        
        cpuTempKeys = checkNulValues(sourceArray: modelSensors[.CPU]?.map { $0.key } ?? [])
        gpuTempKeys = checkNulValues(sourceArray: modelSensors[.GPU]?.map { $0.key } ?? [])
        fanTempKeys = checkNulValues(sourceArray: defaultSensors[.FAN]?.map { $0.key } ?? [])
        fanSpeedKeys = defaultSensors[.FAN_SPEED]?.map { $0.key } ?? []
        systemPowerKeys = defaultSensors[.POWER]?.map { $0.key } ?? []
        systemAdapterKeys = defaultSensors[.ADAPTER]?.map { $0.key } ?? []
        systemBatteryKeys = defaultSensors[.BATTERY]?.map { $0.key } ?? []
        
        self.update()
    }
    
    deinit {
        IOServiceClose(con)
    }
    
    private func checkNulValues(sourceArray: [String]) -> [String] {
        var resultArray = sourceArray
        
        // clear nullable values
        for value in sourceArray {
            if read(value) == 0.0 {
                resultArray.remove(at: resultArray.firstIndex(of: value)!)
            }
        }
        return resultArray
    }
    
    private func callStructMethod(_ input: inout AppleSMCKey, _ output: inout AppleSMCKey) throws {
        var outsize = MemoryLayout<AppleSMCKey>.size
        let result = IOConnectCallStructMethod(con, KERNEL_INDEX_SMC, &input, MemoryLayout<AppleSMCKey>.size, &output, &outsize)
        guard result == kIOReturnSuccess else { throw MyError.iokit(result) }
    }
    
    private func readKey(_ input: inout AppleSMCKey) throws {
        var output = AppleSMCKey()
        
        input.data8 = SMC_CMD_READ_KEYINFO
        try callStructMethod(&input, &output)
        
        input.info.size = output.info.size
        input.info.type = output.info.type
        input.data8 = SMC_CMD_READ_BYTES
        
        try callStructMethod(&input, &output)
        
        input.bytes = output.bytes
    }
    
    private func read(_ key: String) -> Double {
        var input = AppleSMCKey()
        input.key = try! AppleSMC4Chars(key)
        input.info.size = 4
        input.info.type = try! AppleSMC4Chars("flt ")
        try! readKey(&input)
        var ret: Float = 0.0
        memmove(&ret, &input.bytes, 4)
        return Double(String(format: "%0.1f",ret)) ?? 0.0
    }
    
    public func update () {
        // get SMC data
        cpuTemp = cpuTempKeys.reduce(0,{ result, sensor in max(result, self.read(sensor))})
        gpuTemp = gpuTempKeys.reduce(0,{ result, sensor in max(result, self.read(sensor))})
        
        // Only update fan data if fan is present
        if !isFanlessModel && fanTempKeys.count > 0 {
            fanTemp = fanTempKeys.reduce(0,{ result, sensor in max(result, self.read(sensor))})
        } else {
            fanTemp = 0.0
        }
        
        fanSpeed = []
        
        if !isFanlessModel {
            for key in fanSpeedKeys {
               fanSpeed.append(Int(self.read(key)))
            }
        }
        
        systemPower = Int(systemPowerKeys.reduce(0, { sum, sensor in round(sum + self.read(sensor))}))
        systemAdapter = Int(systemAdapterKeys.reduce(0, { sum, sensor in round(sum + self.read(sensor))}))
        systemBattery = Int(systemBatteryKeys.reduce(0, { sum, sensor in round(sum + self.read(sensor))}))
    }
}

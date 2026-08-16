//  Copyright © MonitorControl. JoniVR, theOneyouseek, waydabber, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import IOKit

class DDC: NSObject {
    static let MAX_MATCH_SCORE: Int = 20
    static let ARM64_DDC_7BIT_ADDRESS: UInt8 = 0x37
    static let ARM64_DDC_DATA_ADDRESS: UInt8 = 0x51
    
    struct IORegService: @unchecked Sendable {
        var edidUUID: String = ""
        var productName: String = ""
        var serialNumber: Int64 = 0
        var location: String = ""
        var ioDisplayLocation: String = ""
        var service: IOAVService?
        var serviceLocation: Int = 0
    }
    
    struct ServiceMatch: @unchecked Sendable {
        var displayID: CGDirectDisplayID = 0
        var service: IOAVService?
        var serviceLocation: Int = 0
    }
    
    static func getServiceMatches(displayIDs: [CGDirectDisplayID]) -> [ServiceMatch] {
        let ioregServicesForMatching = self.getIoregServicesForMatching()
        var matchedDisplayServices: [ServiceMatch] = []
        var scoredCandidateDisplayServices: [Int: [ServiceMatch]] = [:]
        for displayID in displayIDs {
            for ioregServiceForMatching in ioregServicesForMatching {
                let score = self.ioregMatchScore(displayID: displayID, ioregEdidUUID: ioregServiceForMatching.edidUUID, ioDisplayLocation: ioregServiceForMatching.ioDisplayLocation, ioregProductName: ioregServiceForMatching.productName, ioregSerialNumber: ioregServiceForMatching.serialNumber, serviceLocation: ioregServiceForMatching.serviceLocation)
                let displayService = ServiceMatch(displayID: displayID, service: ioregServiceForMatching.service, serviceLocation: ioregServiceForMatching.serviceLocation)
                if scoredCandidateDisplayServices[score] == nil {
                    scoredCandidateDisplayServices[score] = []
                }
                scoredCandidateDisplayServices[score]?.append(displayService)
            }
        }
        var takenServiceLocations: [Int] = []
        var takenDisplayIDs: [CGDirectDisplayID] = []
        for score in stride(from: self.MAX_MATCH_SCORE, to: 0, by: -1) {
            if let scoredCandidateDisplayService = scoredCandidateDisplayServices[score] {
                for candidateDisplayService in scoredCandidateDisplayService where !(takenDisplayIDs.contains(candidateDisplayService.displayID) || takenServiceLocations.contains(candidateDisplayService.serviceLocation)) {
                    takenDisplayIDs.append(candidateDisplayService.displayID)
                    takenServiceLocations.append(candidateDisplayService.serviceLocation)
                    matchedDisplayServices.append(candidateDisplayService)
                }
            }
        }
        return matchedDisplayServices
    }
    
    static func write(service: IOAVService?, command: UInt8, value: UInt16, writeSleepTime: UInt32? = nil, numOfWriteCycles: UInt8? = nil, numOfRetryAttemps: UInt8? = nil, retrySleepTime: UInt32? = nil) -> Bool {
        var send: [UInt8] = [command, UInt8(value >> 8), UInt8(value & 255)]
        return Self.performDDCCommunication(service: service, send: &send, writeSleepTime: writeSleepTime, numOfWriteCycles: numOfWriteCycles, numOfRetryAttemps: numOfRetryAttemps, retrySleepTime: retrySleepTime)
    }
    
    static func performDDCCommunication(service: IOAVService?, send: inout [UInt8], writeSleepTime: UInt32? = nil, numOfWriteCycles: UInt8? = nil, numOfRetryAttemps: UInt8? = nil, retrySleepTime: UInt32? = nil) -> Bool {
        let dataAddress = ARM64_DDC_DATA_ADDRESS
        var success = false
        guard service != nil else {
            return success
        }
        var packet: [UInt8] = [UInt8(0x80 | (send.count + 1)), UInt8(send.count)] + send + [0] // Note: the last byte is the place of the checksum, see next line!
        packet[packet.count - 1] = self.checksum(chk: send.count == 1 ? ARM64_DDC_7BIT_ADDRESS << 1 : ARM64_DDC_7BIT_ADDRESS << 1 ^ dataAddress, data: &packet, start: 0, end: packet.count - 2)
        for _ in 1 ... (numOfRetryAttemps ?? 4) + 1 {
            for _ in 1 ... max((numOfWriteCycles ?? 2) + 0, 1) {
                usleep(writeSleepTime ?? 10000)
                success = IOAVServiceWriteI2C(service, UInt32(ARM64_DDC_7BIT_ADDRESS), UInt32(dataAddress), &packet, UInt32(packet.count)) == 0
            }
            if success {
                return success
            }
            usleep(retrySleepTime ?? 20000)
        }
        return success
    }
    
    static func checksum(chk: UInt8, data: inout [UInt8], start: Int, end: Int) -> UInt8 {
        var chkd: UInt8 = chk
        for i in start ... end {
            chkd ^= data[i]
        }
        return chkd
    }
    
    static func ioregMatchScore(displayID: CGDirectDisplayID, ioregEdidUUID: String, ioDisplayLocation: String = "", ioregProductName: String = "", ioregSerialNumber: Int64 = 0, serviceLocation _: Int = 0) -> Int {
        var matchScore = 0
        if let dictionary = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary? {
            if let kDisplayYearOfManufacture = dictionary[kDisplayYearOfManufacture] as? Int64, let kDisplayWeekOfManufacture = dictionary[kDisplayWeekOfManufacture] as? Int64, let kDisplayVendorID = dictionary[kDisplayVendorID] as? Int64, let kDisplayProductID = dictionary[kDisplayProductID] as? Int64, let kDisplayVerticalImageSize = dictionary[kDisplayVerticalImageSize] as? Int64, let kDisplayHorizontalImageSize = dictionary[kDisplayHorizontalImageSize] as? Int64 {
                struct KeyLoc {
                    var key: String
                    var loc: Int
                }
                let edidUUIDSearchKeys: [KeyLoc] = [
                    // Vendor ID
                    KeyLoc(key: String(format: "%04x", UInt16(max(0, min(kDisplayVendorID, 256 * 256 - 1)))).uppercased(), loc: 0),
                    // Product ID
                    KeyLoc(key: String(format: "%02x", UInt8((UInt16(max(0, min(kDisplayProductID, 256 * 256 - 1))) >> (0 * 8)) & 0xFF)).uppercased()
                           + String(format: "%02x", UInt8((UInt16(max(0, min(kDisplayProductID, 256 * 256 - 1))) >> (1 * 8)) & 0xFF)).uppercased(), loc: 4),
                    // Manufacture date
                    KeyLoc(key: String(format: "%02x", UInt8(max(0, min(kDisplayWeekOfManufacture, 256 - 1)))).uppercased()
                           + String(format: "%02x", UInt8(max(0, min(kDisplayYearOfManufacture - 1990, 256 - 1)))).uppercased(), loc: 19),
                    // Image size
                    KeyLoc(key: String(format: "%02x", UInt8(max(0, min(kDisplayHorizontalImageSize / 10, 256 - 1)))).uppercased()
                           + String(format: "%02x", UInt8(max(0, min(kDisplayVerticalImageSize / 10, 256 - 1)))).uppercased(), loc: 30),
                ]
                for searchKey in edidUUIDSearchKeys where searchKey.key != "0000" && searchKey.key == ioregEdidUUID.prefix(searchKey.loc + 4).suffix(4) {
                    matchScore += 1
                }
            }
            if ioDisplayLocation != "", let kIODisplayLocation = dictionary[kIODisplayLocationKey] as? String, ioDisplayLocation == kIODisplayLocation {
                matchScore += 10
            }
            if ioregProductName != "", let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList["en_US"] ?? nameList.first?.value, name.lowercased() == ioregProductName.lowercased() {
                matchScore += 1
            }
            if ioregSerialNumber != 0, let serial = dictionary[kDisplaySerialNumber] as? Int64, serial == ioregSerialNumber {
                matchScore += 1
            }
        }
        return matchScore
    }
    
    static func ioregIterateToNextObjectOfInterest(interests: [String], iterator: inout io_iterator_t) -> (name: String, entry: io_service_t, preceedingEntry: io_service_t)? {
        var entry: io_service_t = IO_OBJECT_NULL
        var preceedingEntry: io_service_t = IO_OBJECT_NULL
        let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
        defer {
            name.deallocate()
        }
        while true {
            preceedingEntry = entry
            entry = IOIteratorNext(iterator)
            guard IORegistryEntryGetName(entry, name) == KERN_SUCCESS, entry != MACH_PORT_NULL else {
                break
            }
            let nameString = String(cString: name)
            for interest in interests where entry != IO_OBJECT_NULL && nameString.contains(interest) {
                return (nameString, entry, preceedingEntry)
            }
        }
        return nil
    }
    
    static func getIORegServiceAppleCDC2Properties(entry: io_service_t) -> IORegService {
        var ioregService = IORegService()
        if let unmanagedEdidUUID = IORegistryEntryCreateCFProperty(entry, "EDID UUID" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let edidUUID = unmanagedEdidUUID.takeRetainedValue() as? String {
            ioregService.edidUUID = edidUUID
        }
        let cpath = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
        IORegistryEntryGetPath(entry, kIOServicePlane, cpath)
        ioregService.ioDisplayLocation = String(cString: cpath)
        if let unmanagedDisplayAttrs = IORegistryEntryCreateCFProperty(entry, "DisplayAttributes" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let displayAttrs = unmanagedDisplayAttrs.takeRetainedValue() as? NSDictionary {
            if let productAttrs = displayAttrs.value(forKey: "ProductAttributes") as? NSDictionary {
                if let productName = productAttrs.value(forKey: "ProductName") as? String {
                    ioregService.productName = productName
                }
                if let serialNumber = productAttrs.value(forKey: "SerialNumber") as? Int64 {
                    ioregService.serialNumber = serialNumber
                }
            }
        }
        return ioregService
    }
    
    static func setIORegServiceDCPAVServiceProxy(entry: io_service_t, ioregService: inout IORegService) {
        if let unmanagedLocation = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let location = unmanagedLocation.takeRetainedValue() as? String {
            ioregService.location = location
            if location == "External" {
                ioregService.service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() as IOAVService
            }
        }
    }
    
    static func getIoregServicesForMatching() -> [IORegService] {
        var serviceLocation = 0
        var ioregServicesForMatching: [IORegService] = []
        let ioregRoot: io_registry_entry_t = IORegistryGetRootEntry(kIOMainPortDefault)
        defer {
            IOObjectRelease(ioregRoot)
        }
        var iterator = io_iterator_t()
        defer {
            IOObjectRelease(iterator)
        }
        var ioregService = IORegService()
        guard IORegistryEntryCreateIterator(ioregRoot, "IOService", IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
            return ioregServicesForMatching
        }
        let keyDCPAVServiceProxy = "DCPAVServiceProxy"
        let keysFramebuffer = ["AppleCLCD2", "IOMobileFramebufferShim"]
        while true {
            guard let objectOfInterest = ioregIterateToNextObjectOfInterest(interests: [keyDCPAVServiceProxy] + keysFramebuffer, iterator: &iterator) else {
                break
            }
            if keysFramebuffer.contains(objectOfInterest.name) {
                ioregService = self.getIORegServiceAppleCDC2Properties(entry: objectOfInterest.entry)
                serviceLocation += 1
                ioregService.serviceLocation = serviceLocation
            } else if objectOfInterest.name == keyDCPAVServiceProxy {
                self.setIORegServiceDCPAVServiceProxy(entry: objectOfInterest.entry, ioregService: &ioregService)
                ioregServicesForMatching.append(ioregService)
            }
        }
        return ioregServicesForMatching
    }
    
}

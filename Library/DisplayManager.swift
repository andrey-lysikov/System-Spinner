//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others, Andrey Lysikov
//  SPDX-License-Identifier: Apache-2.0

import CoreGraphics
import Foundation
import AppKit

enum Command: UInt8 {
    case none = 0
    case luminance = 0x10
    case audioSpeakerVolume = 0x62
    case audioMuteScreenBlank = 0x8D
    case contrast = 0x12
    public static let brightness = luminance
}

class Display: Equatable {
    public let identifier: CGDirectDisplayID
    public var name: String
    public var savedVolume: Float = 0
    public var displays: [Display] = []
    
    public static func == (lhs: Display, rhs: Display) -> Bool {
        lhs.identifier == rhs.identifier
    }
    
    init(_ identifier: CGDirectDisplayID, name: String) {
        self.identifier = identifier
        self.name = name
    }
    
    public func isBuiltIn() -> Bool {
        if CGDisplayIsBuiltin(self.identifier) != 0 {
            return true
        } else {
            return false
        }
    }
    
    public func isHDR() -> Bool {
        if let mainScreen = NSScreen.main {
            if mainScreen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0 {
                return true
            }
        }
        return false
    }
    
    public func getCurrentBrightness() -> Float {
        if let brightness = Float(UserDefaults.standard.string(forKey: "brightness." + self.name) ?? "") {
            return brightness
        }
        return 100 // default full
    }
    
    public func getCurrentVolume() -> Float {
        if let volume = Float(UserDefaults.standard.string(forKey: "volume." + self.name) ?? "") {
            return volume
        }
        return 0 // default zero
    }
    
    public func setDirectBrightness(valueBrightness: Float) {
        UserDefaults.standard.set(valueBrightness, forKey: "brightness." + self.name)
    }
    
    public func setDirectVolume(valueVolume: Float) {
        UserDefaults.standard.set(valueVolume, forKey: "volume." + self.name)
    }
}

class DisplayManager {
    public static let shared = DisplayManager()
    public var displays: [Display] = []
    public let globalDDCQueue = DispatchQueue(label: "Global DDC queue")
    private var audioControlTargetDisplays: [OtherDisplay] = []
    private let correctionValue: Float = 6.25
    
    static func getDisplayNameByID(displayID: CGDirectDisplayID) -> String {
        if let dictionary = (CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], var name = nameList[Locale.current.identifier] ?? nameList["en_US"] ?? nameList.first?.value {
            if CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0 {
                let mirroredDisplayID = CGDisplayMirrorsDisplay(displayID)
                if mirroredDisplayID != 0, let dictionary = (CoreDisplay_DisplayCreateInfoDictionary(mirroredDisplayID)?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let mirroredName = nameList[Locale.current.identifier] ?? nameList["en_US"] ?? nameList.first?.value {
                    name.append(" | " + mirroredName)
                }
            }
            return name
        }
        return "Unknown"
    }
    
    private static func getDisplayRawNameByID(displayID: CGDirectDisplayID) -> String {
        if let dictionary = (CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList["en_US"] ?? nameList.first?.value {
            return name
        }
        return ""
    }
    
    private static func isDummy(displayID: CGDirectDisplayID) -> Bool {
        let vendorNumber = CGDisplayVendorNumber(displayID)
        let rawName = getDisplayRawNameByID(displayID: displayID)
        if rawName.lowercased().contains("dummy") || (self.isVirtual(displayID: displayID) && vendorNumber == UInt32(0xF0F0)) {
            return true
        }
        return false
    }
    
    private static func isVirtual(displayID: CGDirectDisplayID) -> Bool {
        var isVirtual = false
        if let dictionary = (CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary?) {
            let isVirtualDevice = dictionary["kCGDisplayIsVirtualDevice"] as? Bool
            let displayIsAirplay = dictionary["kCGDisplayIsAirPlay"] as? Bool
            if isVirtualDevice ?? displayIsAirplay ?? false {
                isVirtual = true
            }
        }
        return isVirtual
    }
    
    private static func isAppleDisplay(displayID: CGDirectDisplayID) -> Bool {
        if CGDisplayVendorNumber(displayID) != 1552 {
            return CGDisplayIsBuiltin(displayID) != 0
        } else {
            var brightness: Float = -1
            let ret = DisplayServicesGetBrightness(displayID, &brightness)
            if ret == 0, brightness >= 0 { // If brightness read appears to be successful using DisplayServices then it should be an Apple display
                return true
            }
        }
        return CGDisplayIsBuiltin(displayID) != 0
    }
    
    private func updateArm64AVServices() {
        if Arm64DDC.isArm64 {
            var displayIDs: [CGDirectDisplayID] = []
            for otherDisplay in self.getOtherDisplays() {
                displayIDs.append(otherDisplay.identifier)
            }
            for serviceMatch in Arm64DDC.getServiceMatches(displayIDs: displayIDs) {
                for otherDisplay in self.getOtherDisplays() where otherDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
                    otherDisplay.arm64avService = serviceMatch.service
                    if serviceMatch.discouraged {
                        otherDisplay.isDiscouraged = true
                    } else if serviceMatch.dummy {
                        otherDisplay.isDiscouraged = true
                    } else {
                        otherDisplay.arm64ddc = true
                    }
                }
            }
        }
    }
    
    public func configureDisplays() {
        self.displays = []
        CGDisplayRestoreColorSyncSettings()
        var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success else {
            return
        }
        
        for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
            let name = DisplayManager.getDisplayNameByID(displayID: onlineDisplayID)
            let id = onlineDisplayID
            
            if !DisplayManager.isDummy(displayID: onlineDisplayID) && !DisplayManager.isVirtual(displayID: onlineDisplayID) {
                if DisplayManager.isAppleDisplay(displayID: onlineDisplayID) {
                    let appleDisplay = AppleDisplay(id, name: "Apple " + name)
                    self.displays.append(appleDisplay)
                } else {
                    let otherDisplay = OtherDisplay(id, name: name)
                    self.displays.append(otherDisplay)
                }
            }
        }
        updateArm64AVServices()
    }
    
    public func getOtherDisplays() -> [OtherDisplay] {
        self.displays.compactMap { $0 as? OtherDisplay }
    }
    
    private func normalizedName(_ name: String) -> String {
        var normalizedName = name.replacingOccurrences(of: "(", with: "")
        normalizedName = normalizedName.replacingOccurrences(of: ")", with: "")
        normalizedName = normalizedName.replacingOccurrences(of: " ", with: "")
        for i in 0 ... 9 {
            normalizedName = normalizedName.replacingOccurrences(of: String(i), with: "")
        }
        return normalizedName
    }
    
    public func isAppleDisplayPresent() -> Bool {
        for display in DisplayManager.shared.displays where display.isBuiltIn() {
            return true
        }
        return false
    }
    
    public func hasBrightnessControll() -> Bool {
        var brightness = false
        for display in DisplayManager.shared.displays where !display.isBuiltIn() && !display.isHDR() {
            brightness = true
        }
        
        return brightness
    }
    
    public func toggleMute() {
        for display in displays {
            var volumeValue = display.getCurrentVolume()
                if volumeValue == 0 {
                    volumeValue = display.savedVolume
                } else {
                    display.savedVolume = volumeValue
                    volumeValue = 0
                }
            display.setDirectVolume(valueVolume: Float(volumeValue))
        }
    }
    
    public func setVolume(isUp: Bool) {
        for display in displays {
            var volumeValue = display.getCurrentVolume()
            if isUp && volumeValue < correctionValue {
                if volumeValue == 0 {
                        volumeValue = correctionValue / 8
                    } else {
                        volumeValue = volumeValue * 2
                }
            } else if !isUp && volumeValue <= correctionValue && volumeValue > correctionValue / 8 {
                    volumeValue = volumeValue / 2
                } else {
                    volumeValue = volumeValue + (isUp ? correctionValue : -correctionValue)
                }

            if volumeValue < 0 {
                volumeValue = 0
            } else if volumeValue > 100 {
                volumeValue = 100
            }
            display.setDirectVolume(valueVolume: Float(volumeValue))
        }
    }
    
    public func setBrightness(isUp: Bool) {
        for display in displays {
            var brightnessValue = display.getCurrentBrightness() + (isUp ? correctionValue : -correctionValue)
            if brightnessValue < 0 {
                brightnessValue = 0
            } else if brightnessValue > 100 {
                brightnessValue = 100
            }
            display.setDirectBrightness(valueBrightness: Float(brightnessValue))
        }
    }

    public static func engageMirror() -> Bool {
        var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success, displayCount > 1 else {
            return false
        }
        // Break display mirror if there is any
        var mirrorBreak = false
        var displayConfigRef: CGDisplayConfigRef?
        for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
            if CGDisplayIsInHWMirrorSet(onlineDisplayID) != 0 || CGDisplayIsInMirrorSet(onlineDisplayID) != 0 {
                if mirrorBreak == false {
                    CGBeginDisplayConfiguration(&displayConfigRef)
                }
                CGConfigureDisplayMirrorOfDisplay(displayConfigRef, onlineDisplayID, kCGNullDirectDisplay)
                mirrorBreak = true
            }
        }
        if mirrorBreak {
            CGCompleteDisplayConfiguration(displayConfigRef, CGConfigureOption.permanently)
            return true
        }
        // Build display mirror
        var mainDisplayId = kCGNullDirectDisplay
        for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
            if CGDisplayIsBuiltin(onlineDisplayID) == 0, mainDisplayId == kCGNullDirectDisplay {
                mainDisplayId = onlineDisplayID
            }
        }
        guard mainDisplayId != kCGNullDirectDisplay else {
            return false
        }
        CGBeginDisplayConfiguration(&displayConfigRef)
        for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 && onlineDisplayID != mainDisplayId {
            CGConfigureDisplayMirrorOfDisplay(displayConfigRef, onlineDisplayID, mainDisplayId)
        }
        CGCompleteDisplayConfiguration(displayConfigRef, CGConfigureOption.permanently)
        return true
    }
}

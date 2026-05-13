//  Copyright © MonitorControl. JoniVR, theOneyouseek, waydabber, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

class DisplayManager {
    public static let shared = DisplayManager()
    public var displays: [Display] = []
    public let globalDDCQueue = DispatchQueue(label: "Global DDC queue")
    private var audioControlTargetDisplays: [OtherDisplay] = []
    private let osd = OSD()
    
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
    
    private func updateAVServices() {
            var displayIDs: [CGDirectDisplayID] = []
            for otherDisplay in self.getOtherDisplays() {
                displayIDs.append(otherDisplay.identifier)
            }
            for serviceMatch in DDC.getServiceMatches(displayIDs: displayIDs) {
                for otherDisplay in self.getOtherDisplays() where otherDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
                    otherDisplay.ddcService = serviceMatch.service
                    if serviceMatch.discouraged {
                        otherDisplay.isDiscouraged = true
                    } else if serviceMatch.dummy {
                        otherDisplay.isDiscouraged = true
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
        updateAVServices()
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
        for display in displays where display.isBuiltIn() {
            return true
        }
        return false
    }
    
    public func hasBrightnessControll() -> Bool {
        var brightness = false
        for display in displays where !display.isBuiltIn() && !display.isHDR() {
            brightness = true
        }
        return brightness
    }
    
    public func toggleMute() -> MediaKeyHandlingResult {
        var returnControl: MediaKeyHandlingResult = .passThrough
        
        for display in displays {
            var volumeValue = display.getCurrentVolume()
            if volumeValue == 0 {
                volumeValue = display.savedVolume
            } else {
                display.savedVolume = volumeValue
                volumeValue = 0
            }
            
            if display.hasVolumeControl() || alwaysUseCustomOSD {
                returnControl = .consumed(didChange: true)
                osd.showOSD(value: Float(volumeValue),isDisplay: false, separators: adjSteps)
            }
            
            display.setVolume(valueVolume: Float(volumeValue))
        }
        
        return returnControl
    }
    
    public func setVolume(isUp: Bool) -> MediaKeyHandlingResult {
        let step:Float = 100 / Float(adjSteps)
        var returnControl: MediaKeyHandlingResult = .passThrough
        
        for display in displays {
            var volumeValue = (display.getCurrentVolume()/step).rounded() * step + (isUp ? step : -step)
            
            if volumeValue < 0 {
                volumeValue = 0
            } else if volumeValue > 100 {
                volumeValue = 100
            }
            
            if display.hasVolumeControl() || alwaysUseCustomOSD {
                returnControl = .consumed(didChange: true)
                osd.showOSD(value: Float(volumeValue),isDisplay: false, separators: adjSteps)
            }
            
            display.setVolume(valueVolume: Float(volumeValue))
        }
        
        return returnControl
    }
    
    public func setBrightness(isUp: Bool) -> MediaKeyHandlingResult {
        let step:Float = 100 / Float(adjSteps)
        
        if !hasBrightnessControll() && !alwaysUseCustomOSD {
            return .passThrough
        }
        
        for display in displays {
               var brightnessValue = (display.getCurrentBrightness()/step).rounded() * step + (isUp ? step : -step)
            if brightnessValue < 0 {
                brightnessValue = 0
            } else if brightnessValue > 100 {
                brightnessValue = 100
            }
            
            osd.showOSD(value: Float(brightnessValue),isDisplay: true, separators: adjSteps)
            display.setBrightness(valueBrightness: Float(brightnessValue))
        }
        return .consumed(didChange: true)
    }
}

//  Copyright © MonitorControl. JoniVR, theOneyouseek, waydabber, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

@MainActor
class DisplayManager {
    public static let shared = DisplayManager()
    public let globalDDCQueue = DispatchQueue(label: "Global DDC queue")
    public var displays: [Display] = []
    private let osd = OSDController.shared
    private let preferences = Preferences.shared
    
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
    
    private func applyAVServices(_ serviceMatches: [DDC.ServiceMatch]) {
        for serviceMatch in serviceMatches {
            for otherDisplay in self.getOtherDisplays()
            where otherDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
                otherDisplay.ddcService = serviceMatch.service
            }
        }
    }

    public func configureDisplays(completion: (([Display]) -> Void)? = nil) {
        self.displays = []
        CGDisplayRestoreColorSyncSettings()
        var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success else {
            completion?([])
            return
        }

        for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
            let name = DisplayManager.getDisplayNameByID(displayID: onlineDisplayID)
            let id = onlineDisplayID

            if !DisplayManager.isDummy(displayID: onlineDisplayID) && !DisplayManager.isVirtual(displayID: onlineDisplayID) {
                if DisplayManager.isAppleDisplay(displayID: onlineDisplayID) {
                    self.displays.append(AppleDisplay(id, name: "Apple " + name))
                } else {
                    self.displays.append(OtherDisplay(id, name: name))
                }
            }
        }

        completion?(self.displays)

        let displayIDs = self.getOtherDisplays().map { $0.identifier }
        globalDDCQueue.async {
            let matches = DDC.getServiceMatches(displayIDs: displayIDs)
            Task { @MainActor in
                DisplayManager.shared.applyAVServices(matches)
            }
        }
    }
    
    public func getOtherDisplays() -> [OtherDisplay] {
        self.displays.compactMap { $0 as? OtherDisplay }
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
            
            if display.hasVolumeControl() || preferences.alwaysUsesCustomOSD {
                returnControl = .consumed
                osd.show(value: Float(volumeValue), isDisplay: false, separators: preferences.adjustmentSteps)
            }
            
            display.setVolume(valueVolume: Float(volumeValue))
        }
        
        return returnControl
    }
    
    public func setVolume(isUp: Bool) -> MediaKeyHandlingResult {
        let step:Float = 100 / Float(preferences.adjustmentSteps)
        var returnControl: MediaKeyHandlingResult = .passThrough
        
        for display in displays {
            var volumeValue = (display.getCurrentVolume()/step).rounded() * step + (isUp ? step : -step)
            
            if volumeValue < 0 {
                volumeValue = 0
            } else if volumeValue > 100 {
                volumeValue = 100
            }
            
            if display.hasVolumeControl() || preferences.alwaysUsesCustomOSD {
                returnControl = .consumed
                osd.show(value: Float(volumeValue), isDisplay: false, separators: preferences.adjustmentSteps)
            }
            
            display.setVolume(valueVolume: Float(volumeValue))
        }
        
        return returnControl
    }
    
    public func setBrightness(isUp: Bool) -> MediaKeyHandlingResult {
        let step:Float = 100 / Float(preferences.adjustmentSteps)
        
        if !hasBrightnessControll() && !preferences.alwaysUsesCustomOSD {
            return .passThrough
        }
        
        for display in displays {
               var brightnessValue = (display.getCurrentBrightness()/step).rounded() * step + (isUp ? step : -step)
            if brightnessValue < 0 {
                brightnessValue = 0
            } else if brightnessValue > 100 {
                brightnessValue = 100
            }
            
            osd.show(value: Float(brightnessValue), isDisplay: true, separators: preferences.adjustmentSteps)
            display.setBrightness(valueBrightness: Float(brightnessValue))
        }
        return .consumed
    }
}

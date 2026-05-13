//  Copyright © MonitorControl. JoniVR, theOneyouseek, waydabber, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit
import AudioToolbox

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
    
    public func getDefaultAudioOutputDevice() -> AudioDeviceID {
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceID = kAudioDeviceUnknown
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID)
        
        return deviceID
    }
    
    public func getAudioDeviceVolume(deviceID: AudioDeviceID) -> Float {
        let channelsCount = 2
        var channels = [UInt32](repeating: 0, count: channelsCount)
        var propertySize = UInt32(MemoryLayout<UInt32>.size * channelsCount)
        var leftLevel = Float32(-1)
        var rigthLevel = Float32(-1)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &channels)
        
        if status != noErr { return -1 }
        
        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertySize = UInt32(MemoryLayout<Float32>.size)
        
        propertyAddress.mElement = channels[0]
        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &leftLevel)
        
        propertyAddress.mElement = channels[1]
        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &rigthLevel)
        
        if leftLevel < 0 || rigthLevel < 0 {
            propertySize = UInt32(MemoryLayout<UInt32>.size)
            propertyAddress.mElement = kAudioObjectPropertyElementMain
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &rigthLevel)
            leftLevel = rigthLevel
        }
        
        return (leftLevel + rigthLevel) / 2
    }
    
    public func setAudioDeviceVolume(deviceID: AudioDeviceID, volumeLevel: Float) {
        let channelsCount = 2
        var channels = [UInt32](repeating: 0, count: channelsCount)
        var propertySize = UInt32(MemoryLayout<UInt32>.size * channelsCount)
        var level = volumeLevel

        var propertyAddress = AudioObjectPropertyAddress(
         mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
         mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
         mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &channels)

        if status != noErr { return }

        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertySize = UInt32(MemoryLayout<Float32>.size)
        propertyAddress.mElement = channels[0]

        AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &level)

        propertyAddress.mElement = channels[1]

        AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &level)
        propertyAddress.mElement = kAudioObjectPropertyElementMain
          
        AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &level)
        
    }
    
    public func getDefaultAudioOutputDeviceName(deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var name: CFString? = nil
        let status = withUnsafeMutablePointer(
            to: &name,
            { name in
                let status = AudioObjectGetPropertyData(
                    deviceID,
                    &propertyAddress,
                    0,
                    nil,
                    &propertySize,
                    name
                )
                return status
            }
        )
        if status == noErr, let deviceNameCF = name as String? {
            return deviceNameCF as String
        }

        return ""
    }
    
    public func hasVolumeControl() -> Bool {
        let curentAudioDevice: AudioDeviceID = getDefaultAudioOutputDevice()
        if name == getDefaultAudioOutputDeviceName(deviceID: curentAudioDevice) {
            return true
        } else {
            return false
        }
            
    }
    
    public func saveCurrentBrightness(valueBrightness: Float) {
        UserDefaults.standard.set(valueBrightness, forKey: "brightness." + name)
    }
    
    public func saveCurrentVolume(valueVolume: Float) {
        UserDefaults.standard.set(valueVolume, forKey: "volume." + name)
    }
    
    public func getCurrentBrightness() -> Float {
        if let brightness = Float(UserDefaults.standard.string(forKey: "brightness." + name) ?? "") {
            return brightness
        }
        return 100
    }
    
    public func getCurrentVolume() -> Float {
        let curentAudioDevice: AudioDeviceID =  getDefaultAudioOutputDevice()
        
        if self.name != getDefaultAudioOutputDeviceName(deviceID: curentAudioDevice) {
            return getAudioDeviceVolume(deviceID: curentAudioDevice) * 100
        } else {
            if let volume = Float(UserDefaults.standard.string(forKey: "volume." + name) ?? "") {
                return volume
            }
            return 0
        }
    }
    
    public func setBrightness(valueBrightness: Float) {
        saveCurrentBrightness(valueBrightness: valueBrightness)
    }
    
    public func setVolume(valueVolume: Float) {
        let curentAudioDevice: AudioDeviceID =  getDefaultAudioOutputDevice()
        setAudioDeviceVolume(deviceID: curentAudioDevice, volumeLevel: valueVolume / 100)
        saveCurrentVolume(valueVolume: valueVolume)
    }
}

class AppleDisplay: Display {
    private var displayQueue: DispatchQueue
    
    override init(_ identifier: CGDirectDisplayID, name: String) {
        self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
        super.init(identifier, name: name)
    }
    
    override func getCurrentBrightness() -> Float {
        var brightness: Float = 0
        DisplayServicesGetBrightness(identifier, &brightness)
        return brightness * 100
    }
    
    override func setBrightness(valueBrightness: Float) {
        _ = self.displayQueue.sync {
            DisplayServicesSetBrightness(identifier, valueBrightness / 100)
        }
        saveCurrentBrightness(valueBrightness: valueBrightness)
    }
}

class OtherDisplay: Display {
    enum Command: UInt8 {
        case luminance = 0x10
        case audioSpeakerVolume = 0x62
        public static let brightness = luminance
    }

    var ddcService: IOAVService?
    var isDiscouraged: Bool = false
    let writeDDCQueue = DispatchQueue(label: "Local write DDC queue")
    var writeDDCNextValue: [Command: UInt16] = [:]
    var writeDDCLastSavedValue: [Command: UInt16] = [:]
    
    override init(_ identifier: CGDirectDisplayID, name: String)  {
        super.init(identifier, name: name)
    }
    
    public func writeDDCValues(command: Command, value: UInt16) {
        self.writeDDCQueue.async(flags: .barrier) {
            self.writeDDCNextValue[command] = value
        }
        DisplayManager.shared.globalDDCQueue.async(flags: .barrier) {
            self.asyncPerformWriteDDCValues(command: command)
        }
    }
    
    override func setBrightness(valueBrightness: Float) {
        self.writeDDCValues(command: .brightness, value: UInt16(valueBrightness))
        saveCurrentBrightness(valueBrightness: valueBrightness)
    }
    
    override func setVolume(valueVolume: Float) {
        let curentAudioDevice: AudioDeviceID =  getDefaultAudioOutputDevice()
        
        if name == getDefaultAudioOutputDeviceName(deviceID: curentAudioDevice) {
            self.writeDDCValues(command: .audioSpeakerVolume, value: UInt16(valueVolume))
        } else {
            setAudioDeviceVolume(deviceID: curentAudioDevice, volumeLevel: valueVolume / 100)
        }
        saveCurrentVolume(valueVolume: valueVolume)
    }
    
    func asyncPerformWriteDDCValues(command: Command) {
        var value = UInt16.max
        var lastValue = UInt16.max
        self.writeDDCQueue.sync {
            value = self.writeDDCNextValue[command] ?? UInt16.max
            lastValue = self.writeDDCLastSavedValue[command] ?? UInt16.max
        }
        guard value != UInt16.max, value != lastValue else {
            return
        }
        self.writeDDCQueue.async(flags: .barrier) {
            self.writeDDCLastSavedValue[command] = value
        }

        _ = DDC.write(service: ddcService, command: command.rawValue, value: value)

    }
}

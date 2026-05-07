//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation
import Cocoa
import AudioToolbox

public class AudioManager {

    static func setDeviceVolume(deviceID: AudioDeviceID, volumeLevel: Float) {
        var channels = [UInt32](repeating: 0, count: 2)
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        var level = volumeLevel
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &channels)
        
        if status != noErr { return }
        
        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertySize = UInt32(MemoryLayout<Float32>.size)
    
        AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &level)
    }
    
    static func getDeviceVolume(deviceID: AudioDeviceID) -> Float {
        var channels = [UInt32](repeating: 0, count: 2)
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        var level = Float32(-1)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &channels)
        
        if status != noErr { return -1 }
        
        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertySize = UInt32(MemoryLayout<Float32>.size)
        
        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &level)
        
        return level
    }
    
    static func getDefaultOutputDevice() -> AudioDeviceID {
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceID = kAudioDeviceUnknown
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID)
        
        return deviceID
    }
    
    public static func getDeviceName(deviceID: AudioDeviceID) -> String {
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        var result: CFString = "" as CFString
        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &result)
        
        return result as String
    }
    
}

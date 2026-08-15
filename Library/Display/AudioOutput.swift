//  Copyright © MonitorControl. JoniVR, theOneyouseek, waydabber, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AudioToolbox

enum AudioOutput {
    static var defaultDeviceID: AudioDeviceID {
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceID = kAudioDeviceUnknown

        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))

        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceID)
        return deviceID
    }

    static func name(of deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var name: CFString?

        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, $0)
        }

        guard status == noErr, let name = name as String? else { return "" }
        return name
    }

    static func volume(of deviceID: AudioDeviceID) -> Float {
        let channelsCount = 2
        var channels = [UInt32](repeating: 0, count: channelsCount)
        var propertySize = UInt32(MemoryLayout<UInt32>.size * channelsCount)
        var leftLevel = Float32(-1)
        var rightLevel = Float32(-1)

        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &channels) == noErr else { return -1 }

        address.mSelector = kAudioDevicePropertyVolumeScalar
        propertySize = UInt32(MemoryLayout<Float32>.size)

        address.mElement = channels[0]
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &leftLevel)

        address.mElement = channels[1]
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &rightLevel)

        if leftLevel < 0 || rightLevel < 0 {
            propertySize = UInt32(MemoryLayout<UInt32>.size)
            address.mElement = kAudioObjectPropertyElementMain
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &rightLevel)
            leftLevel = rightLevel
        }

        return (leftLevel + rightLevel) / 2
    }

    static func setVolume(_ level: Float, for deviceID: AudioDeviceID) {
        let channelsCount = 2
        var channels = [UInt32](repeating: 0, count: channelsCount)
        var propertySize = UInt32(MemoryLayout<UInt32>.size * channelsCount)
        var level = level

        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &channels) == noErr else { return }

        address.mSelector = kAudioDevicePropertyVolumeScalar
        propertySize = UInt32(MemoryLayout<Float32>.size)

        address.mElement = channels[0]
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, propertySize, &level)

        address.mElement = channels[1]
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, propertySize, &level)

        address.mElement = kAudioObjectPropertyElementMain
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, propertySize, &level)
    }
}

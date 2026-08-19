//  Copyright © MonitorControl. JoniVR, theOneyouseek, waydabber, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit
import AudioToolbox

@MainActor
class Display: Equatable {
    public let identifier: CGDirectDisplayID
    public var name: String
    public var resolution: CGSize
    public var savedVolume: Float = 0

    nonisolated public static func == (lhs: Display, rhs: Display) -> Bool {
        lhs.identifier == rhs.identifier
    }

    init(_ identifier: CGDirectDisplayID, name: String) {
        self.identifier = identifier
        self.name = name
        self.resolution = Display.pixelResolution(of: identifier)
    }

    public static func pixelResolution(of identifier: CGDirectDisplayID) -> CGSize {
        var size: CGSize

        if let mode = CGDisplayCopyDisplayMode(identifier) {
            size = CGSize(width: mode.pixelWidth, height: mode.pixelHeight)
        } else {
            size = CGSize(width: CGDisplayPixelsWide(identifier), height: CGDisplayPixelsHigh(identifier))
        }

        if abs(CGDisplayRotation(identifier).truncatingRemainder(dividingBy: 180)) > 45 {
            size = CGSize(width: size.height, height: size.width)
        }

        return size
    }

    @discardableResult
    public func refreshResolution() -> CGSize {
        resolution = Display.pixelResolution(of: identifier)
        return resolution
    }

    public func isBuiltIn() -> Bool {
        CGDisplayIsBuiltin(identifier) != 0
    }

    public func isHDR() -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == identifier }) else { return false }
        return screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0
    }

    public func hasVolumeControl() -> Bool {
        name == AudioOutput.name(of: AudioOutput.defaultDeviceID)
    }

    public func saveCurrentBrightness(valueBrightness: Float) {
        Preferences.shared.setBrightness(valueBrightness, forDisplay: name)
    }

    public func saveCurrentVolume(valueVolume: Float) {
        Preferences.shared.setVolume(valueVolume, forDisplay: name)
    }

    public func getCurrentBrightness() -> Float {
        Preferences.shared.brightness(forDisplay: name) ?? 100
    }

    public func getCurrentVolume() -> Float {
        let deviceID = AudioOutput.defaultDeviceID

        if name != AudioOutput.name(of: deviceID) {
            return AudioOutput.volume(of: deviceID) * 100
        }
        return Preferences.shared.volume(forDisplay: name) ?? 0
    }

    public func setBrightness(valueBrightness: Float) {
        saveCurrentBrightness(valueBrightness: valueBrightness)
    }

    public func setVolume(valueVolume: Float) {
        AudioOutput.setVolume(valueVolume / 100, for: AudioOutput.defaultDeviceID)
        saveCurrentVolume(valueVolume: valueVolume)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

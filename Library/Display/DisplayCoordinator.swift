//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa
import AppKit

final class DisplayCoordinator {
    static let shared = DisplayCoordinator()

    var onDisplaysChanged: (([Display]) -> Void)?

    private var pendingRefresh: DispatchWorkItem?
    private static let debounceDelay: TimeInterval = 1.0

    private init() {}

    func start() {
        CGDisplayRegisterReconfigurationCallback({ _, _, _ in
            DisplayCoordinator.shared.setNeedsRefresh()
        }, nil)
        setNeedsRefresh()
    }

    func setNeedsRefresh() {
        DispatchQueue.main.async { [self] in
            pendingRefresh?.cancel()

            let work = DispatchWorkItem { [weak self] in self?.refresh() }
            pendingRefresh = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceDelay, execute: work)
        }
    }

    private func refresh() {
        DisplayManager.shared.configureDisplays { [weak self] displays in
            self?.onDisplaysChanged?(displays)

            if AccessibilityPermission.check() {
                MediaKeyMonitor.shared.start()
            }

            UpdateChecker.shared.check()
        }
    }
}

final class AppleDisplay: Display {
    private let displayQueue: DispatchQueue

    override init(_ identifier: CGDirectDisplayID, name: String) {
        displayQueue = DispatchQueue(label: "displayQueue-\(identifier)")
        super.init(identifier, name: name)
    }

    override func getCurrentBrightness() -> Float {
        var brightness: Float = 0
        DisplayServicesGetBrightness(identifier, &brightness)
        return brightness * 100
    }

    override func setBrightness(valueBrightness: Float) {
        displayQueue.sync {
            _ = DisplayServicesSetBrightness(identifier, valueBrightness / 100)
        }
        saveCurrentBrightness(valueBrightness: valueBrightness)
    }
}

final class OtherDisplay: Display {
    enum Command: UInt8 {
        case luminance = 0x10
        case audioSpeakerVolume = 0x62

        static let brightness = luminance
    }

    var ddcService: IOAVService?
    var isDiscouraged: Bool = false

    private let writeDDCQueue = DispatchQueue(label: "Local write DDC queue")
    private var writeDDCNextValue: [Command: UInt16] = [:]
    private var writeDDCLastSavedValue: [Command: UInt16] = [:]

    override func setBrightness(valueBrightness: Float) {
        writeDDCValues(command: .brightness, value: UInt16(valueBrightness))
        saveCurrentBrightness(valueBrightness: valueBrightness)
    }

    override func setVolume(valueVolume: Float) {
        let deviceID = AudioOutput.defaultDeviceID

        if name == AudioOutput.name(of: deviceID) {
            writeDDCValues(command: .audioSpeakerVolume, value: UInt16(valueVolume))
        } else {
            AudioOutput.setVolume(valueVolume / 100, for: deviceID)
        }
        saveCurrentVolume(valueVolume: valueVolume)
    }

    private func writeDDCValues(command: Command, value: UInt16) {
        writeDDCQueue.async(flags: .barrier) {
            self.writeDDCNextValue[command] = value
        }
        DisplayManager.shared.globalDDCQueue.async(flags: .barrier) {
            self.performWriteDDCValues(command: command)
        }
    }

    private func performWriteDDCValues(command: Command) {
        var value = UInt16.max
        var lastValue = UInt16.max

        writeDDCQueue.sync {
            value = writeDDCNextValue[command] ?? UInt16.max
            lastValue = writeDDCLastSavedValue[command] ?? UInt16.max
        }

        guard value != UInt16.max, value != lastValue else { return }

        writeDDCQueue.async(flags: .barrier) {
            self.writeDDCLastSavedValue[command] = value
        }

        _ = DDC.write(service: ddcService, command: command.rawValue, value: value)
    }
}

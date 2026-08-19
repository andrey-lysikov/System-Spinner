//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit

@MainActor
final class KeyboardBacklight {
    static let shared = KeyboardBacklight()

    private typealias CopyIDs = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?
    private typealias BoolForKeyboard = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias BrightnessForKeyboard = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetBrightness = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool

    private static let frameworkPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
    private static let copyIDsSelector = Selector(("copyKeyboardBacklightIDs"))
    private static let isBuiltInSelector = Selector(("isKeyboardBuiltIn:"))
    private static let brightnessSelector = Selector(("brightnessForKeyboard:"))
    private static let setBrightnessSelector = Selector(("setBrightness:forKeyboard:"))

    private let client: NSObject?
    private let osd = OSDController.shared
    private let preferences = Preferences.shared
    private var didRestoreBrightness = false

    private init() {
        dlopen(Self.frameworkPath, RTLD_LAZY)

        guard let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            client = nil
            return
        }

        let instance = type.init()
        let selectors = [Self.copyIDsSelector, Self.brightnessSelector, Self.setBrightnessSelector]
        client = selectors.allSatisfy { instance.responds(to: $0) } ? instance : nil
    }

    public var isAvailable: Bool {
        keyboardID != nil
    }

    public var brightness: Float {
        guard let client, let keyboardID,
              let method = client.method(for: Self.brightnessSelector)
        else {
            return 0
        }

        let read = unsafeBitCast(method, to: BrightnessForKeyboard.self)
        return read(client, Self.brightnessSelector, keyboardID) * 100
    }

    @discardableResult
    public func setBrightness(_ value: Float) -> Bool {
        guard applyBrightness(value) else { return false }

        preferences.keyboardBacklight = value
        return true
    }

    public func restoreSavedBrightness() {
        guard !didRestoreBrightness else { return }
        didRestoreBrightness = true

        guard preferences.usesKeyboardBacklightKeys, let saved = preferences.keyboardBacklight else { return }

        applyBrightness(saved)
    }

    @discardableResult
    private func applyBrightness(_ value: Float) -> Bool {
        guard let client, let keyboardID,
              let method = client.method(for: Self.setBrightnessSelector)
        else {
            return false
        }

        let write = unsafeBitCast(method, to: SetBrightness.self)
        return write(client, Self.setBrightnessSelector, value / 100, keyboardID)
    }

    public func adjust(isUp: Bool) -> MediaKeyHandlingResult {
        guard isAvailable else { return .passThrough }

        let step = 100 / Float(preferences.adjustmentSteps)
        var value = (brightness / step).rounded() * step + (isUp ? step : -step)

        if value < 0 {
            value = 0
        } else if value > 100 {
            value = 100
        }

        guard setBrightness(value) else { return .passThrough }

        osd.show(value: value, kind: .keyboardBacklight, separators: preferences.adjustmentSteps)
        return .consumed
    }

    private var keyboardID: UInt64? {
        guard let client, let method = client.method(for: Self.copyIDsSelector) else { return nil }

        let copyIDs = unsafeBitCast(method, to: CopyIDs.self)
        guard let identifiers = copyIDs(client, Self.copyIDsSelector)?.takeRetainedValue() as? [NSNumber],
              !identifiers.isEmpty
        else {
            return nil
        }

        if let method = client.method(for: Self.isBuiltInSelector) {
            let isBuiltIn = unsafeBitCast(method, to: BoolForKeyboard.self)
            if let builtIn = identifiers.first(where: { isBuiltIn(client, Self.isBuiltInSelector, $0.uint64Value) }) {
                return builtIn.uint64Value
            }
        }

        return identifiers.first?.uint64Value
    }
}

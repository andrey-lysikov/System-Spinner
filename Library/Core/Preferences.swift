//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation
import Synchronization

/// Значение живёт в памяти под Mutex, поэтому читать его можно из любого потока.
@propertyWrapper
final class Stored<Value: Sendable>: Sendable {
    private let key: String
    private let cached: Mutex<Value>

    init(_ key: String, _ defaultValue: Value) {
        self.key = key
        cached = Mutex(UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue)
    }

    var wrappedValue: Value {
        get { cached.withLock { $0 } }
        set {
            cached.withLock { $0 = newValue }
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

extension String {
    init(cBuffer: [CChar]) {
        let bytes = cBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        self = String(decoding: bytes, as: UTF8.self)
    }
}

/// Все поля — обёртки Stored, потокобезопасные сами по себе; изменяемыми их
/// объявляет генератор property wrapper, отсюда unchecked.
final class Preferences: @unchecked Sendable {
    static let shared = Preferences()

    private init() {}

    @Stored("spinnerActive", "Loader")
    var spinnerName: String

    @Stored("spinnerUpdateInterval", 1.0)
    var updateInterval: Double

    @Stored("enableStatusText", false)
    var showsCPUInMenuBar: Bool

    @Stored("useLocalization", true)
    var usesSystemLanguage: Bool

    @Stored("spinnersEffectSelected", 1)
    var spinnerEffect: Int

    @Stored("spinnersRotationInvert", false)
    var invertsRotation: Bool

    @Stored("alwaysUseCustomOSD", false)
    var alwaysUsesCustomOSD: Bool

    @Stored("adjSteps", 16)
    var adjustmentSteps: Int

    @Stored("usePopUpAnimation", true)
    var usesPopUpAnimation: Bool

    @Stored("showExternalAddress", true)
    var showsExternalAddress: Bool

    @Stored("group.lastCheckVersion", Date.distantPast)
    var lastVersionCheck: Date

    func brightness(forDisplay name: String) -> Float? {
        UserDefaults.standard.object(forKey: "brightness." + name) as? Float
    }

    func setBrightness(_ value: Float, forDisplay name: String) {
        UserDefaults.standard.set(value, forKey: "brightness." + name)
    }

    func volume(forDisplay name: String) -> Float? {
        UserDefaults.standard.object(forKey: "volume." + name) as? Float
    }

    func setVolume(_ value: Float, forDisplay name: String) {
        UserDefaults.standard.set(value, forKey: "volume." + name)
    }
}

func localizedString(_ key: String.LocalizationValue) -> String {
    if Preferences.shared.usesSystemLanguage {
        return String(localized: key)
    } else {
        return String(localized: key, table: "English")
    }
}

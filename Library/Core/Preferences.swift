//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation

@propertyWrapper
final class Stored<Value> {
    private let key: String
    private let defaults: UserDefaults
    private var cached: Value

    init(_ key: String, _ defaultValue: Value, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
        cached = defaults.object(forKey: key) as? Value ?? defaultValue
    }

    var wrappedValue: Value {
        get { cached }
        set {
            cached = newValue
            defaults.set(newValue, forKey: key)
        }
    }
}

final class Preferences {
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

//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation
import Synchronization
import AppKit

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

enum AccentPalette {
    static var normal: NSColor {
        Preferences.shared.usesSystemChartColor ? .controlAccentColor : .labelColor
    }

    static var critical: NSColor {
        Preferences.shared.usesSystemChartColor ? .controlAccentColor : .systemRed
    }
    
    static var iconTint: NSColor? {
        Preferences.shared.usesSystemChartColor ? .controlAccentColor : nil
    }
}

struct SpinnerStyle {
    let name: String
    let frameCount: Int
    let supportsEffect: Bool
    let speedCoefficient: Int
    let isDrawn: Bool

    init(name: String, frameCount: Int, supportsEffect: Bool = true, speedCoefficient: Int = 1, isDrawn: Bool = false) {
        self.name = name
        self.frameCount = frameCount
        self.supportsEffect = supportsEffect
        self.speedCoefficient = speedCoefficient
        self.isDrawn = isDrawn
    }

    func frameName(at index: Int) -> String {
        frameCount == 1 ? name : "\(name) \(index)"
    }
}

enum SpinnerEffect: Int, CaseIterable {
    case original = 1
    case whiteShaded = 2
    case blackShaded = 3
    case automatic = 4

    var title: String {
        switch self {
        case .original: return localizedString("Original")
        case .whiteShaded: return localizedString("White shaded")
        case .blackShaded: return localizedString("Black shaded")
        case .automatic: return localizedString("Automatic Dark/White mode")
        }
    }
}

enum SpinnerCatalog {
    static let all: [SpinnerStyle] = [
        SpinnerStyle(name: "Blue Ball", frameCount: 19),
        SpinnerStyle(name: "Cat", frameCount: 5, speedCoefficient: 2),
        SpinnerStyle(name: "Circles Two", frameCount: 9),
        SpinnerStyle(name: "Cirrcles", frameCount: 8, supportsEffect: false),
        SpinnerStyle(name: "Color Balls", frameCount: 17),
        SpinnerStyle(name: "Color Well", frameCount: 20, supportsEffect: false),
        SpinnerStyle(name: "Delay", frameCount: 17),
        SpinnerStyle(name: "Dots", frameCount: 12, supportsEffect: false),
        SpinnerStyle(name: "Football", frameCount: 24, supportsEffect: false),
        SpinnerStyle(name: "Grey Loader", frameCount: 18, supportsEffect: false),
        SpinnerStyle(name: "Loader", frameCount: 8, supportsEffect: false),
        SpinnerStyle(name: "Pie", frameCount: 6, supportsEffect: false),
        SpinnerStyle(name: "Pikachu", frameCount: 4, speedCoefficient: 2),
        SpinnerStyle(name: "Rainbow Pie", frameCount: 15, supportsEffect: false),
        SpinnerStyle(name: "Recharges", frameCount: 8),
        SpinnerStyle(name: "Rotation Color Well", frameCount: 24, supportsEffect: false, speedCoefficient: 2),
        SpinnerStyle(name: "Sun & Moon", frameCount: 24, isDrawn: true),
        SpinnerStyle(name: "Waves", frameCount: 17),
        SpinnerStyle(name: "Wheel", frameCount: 24),
        SpinnerStyle(name: "App Icon", frameCount: 1),
    ]

    static let fallback = all.first { $0.name == "Loader" } ?? all[0]

    static func style(named name: String) -> SpinnerStyle? {
        all.first { $0.name == name }
    }

    static func style(validating name: String) -> SpinnerStyle {
        style(named: name) ?? fallback
    }
}

/// Adjustment levels from 0 to 100. With `reducesLastStep` the step between 0 and the
/// first division gets extra ticks (8 → 4, 16 → 2, 24 → 1, 32 → none),
/// so the quietest/dimmest non-zero level is not a big jump from zero.
struct AdjustmentScale: Equatable {
    let steps: Int
    let lastStepDivisions: Int

    init(steps: Int, reducesLastStep: Bool = false) {
        self.steps = max(steps, 1)
        lastStepDivisions = reducesLastStep ? Self.lastStepDivisions(steps: self.steps) : 1
    }

    /// Number of parts the first step is split into: extra ticks + 1.
    static func lastStepDivisions(steps: Int) -> Int {
        switch steps {
        case ...8: return 5
        case ...16: return 3
        case ..<Preferences.fineAdjustmentSteps: return 2
        default: return 1
        }
    }

    var levels: [Float] {
        let step = 100 / Float(steps)
        let first = (0 ..< lastStepDivisions).map { Float($0) * step / Float(lastStepDivisions) }
        let regular = (1 ... steps).map { Float($0) * step }
        return first + regular
    }

    func next(from value: Float, isUp: Bool) -> Float {
        let levels = levels
        let nearest = levels.indices.min { abs(levels[$0] - value) < abs(levels[$1] - value) } ?? 0
        let index = min(max(nearest + (isUp ? 1 : -1), 0), levels.count - 1)
        return min(max(levels[index], 0), 100)
    }
}

final class Preferences: @unchecked Sendable {
    static let shared = Preferences()

    private static let obsoleteKeys = ["group.lastCheckVersion"]

    private init() {
        for key in Self.obsoleteKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

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

    static let adjustmentStepChoices = [8, 16, 24, 32]
    static let fineAdjustmentSteps = adjustmentStepChoices.max() ?? 32

    static func adjustmentSteps(base: Int, fine: Bool) -> Int {
        fine ? max(base, fineAdjustmentSteps) : base
    }

    func adjustmentSteps(fine: Bool) -> Int {
        Self.adjustmentSteps(base: adjustmentSteps, fine: fine)
    }

    @Stored("adjReduceLastStep", false)
    var reducesLastStep: Bool

    func adjustmentScale(fine: Bool = false) -> AdjustmentScale {
        AdjustmentScale(steps: adjustmentSteps(fine: fine), reducesLastStep: reducesLastStep)
    }

    @Stored("usePopUpAnimation", true)
    var usesPopUpAnimation: Bool

    @Stored("showExternalAddress", true)
    var showsExternalAddress: Bool

    @Stored("systemChartColor", true)
    var usesSystemChartColor: Bool

    @Stored("keyboardBacklightKeys", false)
    var usesKeyboardBacklightKeys: Bool

    @Stored("smoothMouseScroll", false)
    var usesSmoothScroll: Bool

    @Stored("lastVersionCheckTime", 0.0)
    private var lastVersionCheckTime: TimeInterval

    var lastVersionCheck: Date? {
        get { lastVersionCheckTime > 0 ? Date(timeIntervalSince1970: lastVersionCheckTime) : nil }
        set { lastVersionCheckTime = newValue?.timeIntervalSince1970 ?? 0 }
    }

    func brightness(forDisplay name: String) -> Float? {
        UserDefaults.standard.object(forKey: "brightness." + name) as? Float
    }

    func setBrightness(_ value: Float, forDisplay name: String) {
        UserDefaults.standard.set(value, forKey: "brightness." + name)
    }

    func keyboardBacklight(forKeyboard identifier: UInt64) -> Float? {
        UserDefaults.standard.object(forKey: "keyboardBacklight.\(identifier)") as? Float
            ?? UserDefaults.standard.object(forKey: "keyboardBacklight") as? Float
    }

    func setKeyboardBacklight(_ value: Float, forKeyboard identifier: UInt64) {
        UserDefaults.standard.set(value, forKey: "keyboardBacklight.\(identifier)")
    }

    func volume(forDisplay name: String) -> Float? {
        UserDefaults.standard.object(forKey: "volume." + name) as? Float
    }

    func setVolume(_ value: Float, forDisplay name: String) {
        UserDefaults.standard.set(value, forKey: "volume." + name)
    }
}

private let englishLocalizationPath = Bundle.main.path(forResource: "en", ofType: "lproj")

func localizedString(_ key: String.LocalizationValue) -> String {
    if Preferences.shared.usesSystemLanguage {
        return String(localized: key)
    }

    let bundle = englishLocalizationPath.flatMap(Bundle.init(path:)) ?? .main
    return String(localized: key, bundle: bundle, locale: Locale(identifier: "en"))
}

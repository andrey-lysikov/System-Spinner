//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation

struct SpinnerStyle {
    let name: String
    let frameCount: Int
    let supportsEffect: Bool
    let speedCoefficient: Int
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
        SpinnerStyle(name: "Blue Ball", frameCount: 19, supportsEffect: true, speedCoefficient: 1),
        SpinnerStyle(name: "Cat", frameCount: 5, supportsEffect: true, speedCoefficient: 2),
        SpinnerStyle(name: "Circles Two", frameCount: 9, supportsEffect: true, speedCoefficient: 1),
        SpinnerStyle(name: "Cirrcles", frameCount: 8, supportsEffect: false, speedCoefficient: 1),
        SpinnerStyle(name: "Color Balls", frameCount: 17, supportsEffect: true, speedCoefficient: 1),
        SpinnerStyle(name: "Color Well", frameCount: 20, supportsEffect: false, speedCoefficient: 1),
        SpinnerStyle(name: "Delay", frameCount: 17, supportsEffect: true, speedCoefficient: 1),
        SpinnerStyle(name: "Dots", frameCount: 12, supportsEffect: false, speedCoefficient: 1),
        SpinnerStyle(name: "Grey Loader", frameCount: 18, supportsEffect: false, speedCoefficient: 1),
        SpinnerStyle(name: "Loader", frameCount: 8, supportsEffect: false, speedCoefficient: 1),
        SpinnerStyle(name: "Pie", frameCount: 6, supportsEffect: false, speedCoefficient: 1),
        SpinnerStyle(name: "Pikachu", frameCount: 4, supportsEffect: true, speedCoefficient: 2),
        SpinnerStyle(name: "Rainbow Pie", frameCount: 15, supportsEffect: false, speedCoefficient: 1),
        SpinnerStyle(name: "Recharges", frameCount: 8, supportsEffect: true, speedCoefficient: 1),
        SpinnerStyle(name: "Rotation Color Well", frameCount: 24, supportsEffect: false, speedCoefficient: 2),
        SpinnerStyle(name: "Sun", frameCount: 23, supportsEffect: true, speedCoefficient: 1),
        SpinnerStyle(name: "Waves", frameCount: 17, supportsEffect: true, speedCoefficient: 1),
    ]

    static let fallback = all.first { $0.name == "Loader" } ?? all[0]

    static func style(named name: String) -> SpinnerStyle? {
        all.first { $0.name == name }
    }

    /// Имя приходит из настроек и может не существовать — тогда берётся запасной стиль.
    static func style(validating name: String) -> SpinnerStyle {
        style(named: name) ?? fallback
    }
}

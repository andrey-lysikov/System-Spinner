//  Copyright © (yu) zmlabs, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Combine
import Foundation

struct OSDValue: Equatable {
    enum Kind {
        case volume
        case displayBrightness
        case keyboardBacklight
    }

    var value: Float
    var kind: Kind
    var separatorSteps: Int

    init(value: Float = 0.0, kind: Kind = .volume, separatorSteps: Int = 16) {
        self.value = max(0.0, min(100.0, value))
        self.kind = kind
        self.separatorSteps = separatorSteps
    }

    var iconName: String {
        switch kind {
        case .displayBrightness:
            return value < 80 ? "sun.min" : "sun.max"
        case .keyboardBacklight:
            return value <= 0 ? "keyboard" : "keyboard.fill"
        case .volume:
            switch value {
            case ...0: return "speaker.slash.fill"
            case ..<33: return "speaker.wave.1.fill"
            case ..<66: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        }
    }
}

@MainActor
final class OSDController {
    static let shared = OSDController()
    let valuePublisher = CurrentValueSubject<OSDValue, Never>(OSDValue())
    var currentValue: OSDValue { valuePublisher.value }

    private lazy var window = OSDWindow()
    private var hideTask: Task<Void, Never>?
    private static let visibleDuration: Duration = .seconds(2.5)

    private init() {}

    func show(value: Float, kind: OSDValue.Kind, separators: Int = 16, autoHide: Bool = true) {
        valuePublisher.send(OSDValue(value: value, kind: kind, separatorSteps: separators))

        if autoHide {
            scheduleHide()
        } else {
            hideTask?.cancel()
        }

        window.showWithAnimation()
    }


    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else { return }
            self?.window.hideWithAnimation()
        }
    }
}

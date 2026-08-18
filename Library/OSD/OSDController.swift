//  Copyright © (yu) zmlabs, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Combine
import Foundation

struct OSDValue: Equatable {
    var value: Float
    var isDisplay: Bool
    var separatorSteps: Int

    init(value: Float = 0.0, isDisplay: Bool = false, separatorSteps: Int = 16) {
        self.value = max(0.0, min(100.0, value))
        self.isDisplay = isDisplay
        self.separatorSteps = separatorSteps
    }

    var iconName: String {
        if isDisplay {
            return value < 80 ? "sun.min" : "sun.max"
        }

        switch value {
        case ...0: return "speaker.slash.fill"
        case ..<33: return "speaker.wave.1.fill"
        case ..<66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

@MainActor
final class OSDController {
    static let shared = OSDController()

    /// CurrentValueSubject, чтобы подписчик сразу получал актуальное значение.
    let valuePublisher = CurrentValueSubject<OSDValue, Never>(OSDValue())
    var currentValue: OSDValue { valuePublisher.value }

    private lazy var window = OSDWindow()
    private var hideTask: Task<Void, Never>?
    private static let visibleDuration: Duration = .seconds(2.5)

    private init() {}

    func show(value: Float, isDisplay: Bool, separators: Int = 16, autoHide: Bool = true) {
        valuePublisher.send(OSDValue(value: value, isDisplay: isDisplay, separatorSteps: separators))

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

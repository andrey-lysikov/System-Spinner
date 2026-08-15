//  Copyright © (yu) zmlabs, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import SwiftUI

@MainActor
final class OSDWindow: NSPanel {
    private let hostingView: NSHostingView<OSDView>
    private static let windowSize = NSSize(width: 376, height: 376)

    @objc(_hasActiveAppearance) dynamic func _hasActiveAppearance() -> Bool { true }

    init() {
        hostingView = NSHostingView(rootView: OSDView())

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false

        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.frame = NSRect(origin: .zero, size: Self.windowSize)
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func showWithAnimation() {
        updatePosition()
        hostingView.layoutSubtreeIfNeeded()

        guard Preferences.shared.usesPopUpAnimation else {
            orderFrontRegardless()
            return
        }

        alphaValue = 0.0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func hideWithAnimation() {
        guard Preferences.shared.usesPopUpAnimation else {
            orderOut(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        } completionHandler: {
            Task { @MainActor [weak self] in
                self?.orderOut(nil)
            }
        }
    }

    private func updatePosition() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        setFrame(NSRect(x: frame.minX + (frame.width - Self.windowSize.width) / 2,
                        y: frame.minY,
                        width: Self.windowSize.width,
                        height: Self.windowSize.height),
                 display: false)
    }
}

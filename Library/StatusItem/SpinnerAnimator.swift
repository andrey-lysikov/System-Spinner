//  Copyright © Takuto Nakamura, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa

@MainActor
final class SpinnerAnimator {
    var onFrame: ((NSImage) -> Void)?

    private let preferences = Preferences.shared
    private var style = SpinnerCatalog.fallback
    private var frames: [NSImage] = []
    private var timer: Timer?
    private var currentFrame = 0
    private var currentInterval: Double = -1
    private static let minimumInterval = 1.0 / 120.0

    func load(style: SpinnerStyle, effect: SpinnerEffect) {
        self.style = style
        frames = (0 ..< style.frameCount).compactMap { index in
            guard var image = NSImage(named: style.name + " \(index)") else { return nil }

            let height = NSStatusBar.system.thickness - 2
            image.size = NSSize(width: height / image.size.height * image.size.width, height: height)

            if style.supportsEffect {
                switch effect {
                case .original:
                    image.isTemplate = false
                case .whiteShaded:
                    image.isTemplate = true
                    image = image.imageWithTint(color: NSColor(red: 1, green: 1, blue: 1, alpha: 0.8))
                case .blackShaded:
                    image.isTemplate = true
                    image = image.imageWithTint(color: NSColor(red: 0, green: 0, blue: 0, alpha: 0.8))
                case .automatic:
                    image.isTemplate = true
                }
            }
            return image
        }

        currentFrame = 0
        currentInterval = -1
        if let first = frames.first {
            onFrame?(first)
        }
    }

    func updateSpeed(cpuUsage: Double) {
        guard !frames.isEmpty else { return }

        let load = max(1.0, min(100.0, cpuUsage / Double(frames.count)))
        let interval = max(Self.minimumInterval, 0.25 / load * Double(style.speedCoefficient))

        guard Int(interval * 100) != Int(currentInterval * 100) else { return }

        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        currentInterval = interval
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentInterval = -1
    }

    private func advance() {
        guard !frames.isEmpty else { return }

        currentFrame += preferences.invertsRotation ? -1 : 1
        if currentFrame >= frames.count {
            currentFrame = 0
        } else if currentFrame < 0 {
            currentFrame = frames.count - 1
        }

        onFrame?(frames[currentFrame])
    }
}

extension NSImage {
    func imageWithTint(color: NSColor) -> NSImage {
        guard let tintedImage = self.copy() as? NSImage else { return self }
        tintedImage.lockFocus()

        color.set()
        NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)

        tintedImage.unlockFocus()
        return tintedImage
    }
}

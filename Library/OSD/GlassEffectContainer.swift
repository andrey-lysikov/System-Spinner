//  Copyright © (yu) zmlabs, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct GlassEffectContainer<Content: View>: NSViewRepresentable {
    let tintColor: NSColor?
    let content: Content

    private let cornerRadius: CGFloat = 28
    private let style: NSGlassEffectView.Style = .regular

    init(tintColor: NSColor? = nil, @ViewBuilder content: () -> Content) {
        self.tintColor = tintColor
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content)
    }

    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView(frame: .zero)
        glassView.cornerRadius = cornerRadius
        glassView.style = style
        glassView.tintColor = tintColor

        let hostingView = context.coordinator.hostingView
        hostingView.frame = glassView.bounds
        hostingView.autoresizingMask = [.width, .height]
        glassView.contentView = hostingView
        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style
        nsView.tintColor = tintColor
        context.coordinator.hostingView.rootView = content
        context.coordinator.hostingView.frame = nsView.bounds
    }

    @MainActor
    final class Coordinator {
        let hostingView: NSHostingView<Content>

        init(rootView: Content) {
            hostingView = NSHostingView(rootView: rootView)
        }
    }
}

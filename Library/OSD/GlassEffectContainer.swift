//  Copyright © (yu) zmlabs, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct GlassEffectContainer<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let style: NSGlassEffectView.Style
    let tintColor: NSColor?
    let variant: Int
    let content: Content

    init(
        cornerRadius: CGFloat = 28,
        style: NSGlassEffectView.Style = .regular,
        tintColor: NSColor? = nil,
        variant: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.style = style
        self.tintColor = tintColor
        self.variant = variant
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

        applyVariant(variant, to: glassView)
        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style
        nsView.tintColor = tintColor
        context.coordinator.hostingView.rootView = content
        context.coordinator.hostingView.frame = nsView.bounds
        applyVariant(variant, to: nsView)
    }

    private func applyVariant(_ variant: Int, to view: NSGlassEffectView) {
        guard variant >= 0 else { return }
        setPrivateInt(view, selectors: ["set_variant:", "_setVariant:", "setVariant:"], value: variant)
    }

    private func setPrivateInt(_ view: AnyObject, selectors: [String], value: Int) {
        for name in selectors {
            let selector = Selector(name)
            guard view.responds(to: selector), let method = view.method(for: selector) else { continue }

            typealias MsgSend = @convention(c) (AnyObject, Selector, Int) -> Void
            let function = unsafeBitCast(method, to: MsgSend.self)
            function(view, selector, value)
            break
        }
    }

    final class Coordinator {
        let hostingView: NSHostingView<Content>

        init(rootView: Content) {
            hostingView = NSHostingView(rootView: rootView)
        }
    }
}

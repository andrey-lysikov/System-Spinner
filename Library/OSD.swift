//  Copyright © zmlabs, Andrey Lysikov
//  SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Combine

struct valueState: Equatable {
    var value: Float
    var isDisplay: Bool

    init(value: Float = 0.0, isDisplay: Bool = false ) {
        self.value = max(0.0, min(100.0, value))
        self.isDisplay = isDisplay
    }
    
    var iconName: String {
        if isDisplay {
            if value < 80 {
                return "sun.min"
            } else {
                return "sun.max"
            }
        } else {
            if value <= 0 { return "speaker.slash.fill" }
            if value < 33 { return "speaker.wave.1.fill" }
            if value < 66 { return "speaker.wave.2.fill" }
        }
        return "speaker.wave.3.fill"
    }
}

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

    private func applyVariant(_ variant: Int, to view: NSGlassEffectView) {
        guard variant >= 0 else { return }
        setPrivateInt(view, selectors: ["set_variant:", "_setVariant:", "setVariant:"], value: variant)
    }

    private func setPrivateInt(_ view: AnyObject, selectors: [String], value: Int) {
        for name in selectors {
            let selector = Selector(name)
            guard view.responds(to: selector) else { continue }
            typealias MsgSend = @convention(c) (AnyObject, Selector, Int) -> Void
            guard let method = view.method(for: selector) else { continue }
            let fn = unsafeBitCast(method, to: MsgSend.self)
            fn(view, selector, value)
            break
        }
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

    final class Coordinator {
        let hostingView: NSHostingView<Content>

        init(rootView: Content) {
            hostingView = NSHostingView(rootView: rootView)
        }
    }
}

class OSDWindow: NSPanel {
    private let hostingView: NSHostingView<OSDFactoryView>
    private let window_height: Double = 376
    private let window_width: Double = 376
    
    struct HUDView: View {
        let standardSteps = 16
        let valueState: valueState
        
        var body: some View {
            let content = HStack(spacing: 16) {
                Image(systemName: valueState.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 28)
                    .foregroundStyle(.primary.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.primary.opacity(0.8))
                            if valueState.value > 0 {
                                Capsule()
                                    .fill(Color(.secondaryLabelColor))
                                    .frame(width: geometry.size.width * CGFloat(valueState.value / 100))
                            }
                        }
                    }
                    .frame(height: 4)
                    
                    HStack(spacing: 0) {
                        ForEach(0 ... standardSteps, id: \.self) { index in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(.primary.opacity(0.8))
                                    .frame(width: 1, height: index % 4 == 0 ? 6 : 4)
                            }
                            if index < standardSteps {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(width: 280, height: 64)
            
           GlassEffectContainer() {
               content
           }
        }
    }
    
    struct OSDFactoryView: View {
        @State private var valueState: valueState = .init()
        var body: some View {
            HUDView(valueState: valueState).padding(48)
                .onAppear {
                    valueState = OSD.shared.currentValueState
                }
                .onReceive(OSD.shared.valueChangePublisher.receive(on: RunLoop.main)) {
                    valueState = $0
                }
        }
    }
    
    @objc(_hasActiveAppearance) dynamic func _hasActiveAppearance() -> Bool { true }
    @objc(_hasActiveAppearanceIgnoringKeyFocus) dynamic func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
    @objc(_hasActiveControls) dynamic func _hasActiveControls() -> Bool { true }
    @objc(_hasKeyAppearance) dynamic func _hasKeyAppearance() -> Bool { true }
    @objc(_hasMainAppearance) dynamic func _hasMainAppearance() -> Bool { true }
    
    init() {
        let contentView = OSDFactoryView()
        hostingView = NSHostingView(rootView: contentView)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: window_width, height: window_height),
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
        hostingView.frame = NSRect(x: 0, y: 0, width: window_width, height: window_height)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView
    }

    func updatePosition() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.minX + (screenFrame.width - window_width) / 2
        let y = screenFrame.minY
        setFrame(NSRect(x: x, y: y, width: window_width, height: window_height), display: false)
    }
    
    func showWithAnimation() {
        updatePosition()

        alphaValue = 0.0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func hideWithAnimation() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        } completionHandler: {
            Task { @MainActor [weak self] in
                self?.orderOut(nil)
            }
        }
    }
}

final class OSD {
    private var hudWindow = OSDWindow()
    private var hideTask: Task<Void, Never>?
    private(set) var currentValueState = valueState()
    static let shared = OSD()
    let valueChangePublisher = PassthroughSubject<valueState, Never>()
    
    func showOSD(value:Float, isDisplay:Bool, autoHide:Bool) {
        let newState = valueState(
            value: value,
            isDisplay: isDisplay
        )
        currentValueState = newState
        OSD.shared.valueChangePublisher.send(currentValueState)
        
        if autoHide {
            resetHideTask()
        } else {
            hideTask?.cancel()
        }

        if hudWindow.isVisible == false {
            hudWindow.showWithAnimation()
        }
    }
    
    private func resetHideTask() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))

            if let self, !Task.isCancelled {
                hideHUD()
            }
        }
    }

    private func hideHUD() {
        hudWindow.hideWithAnimation()
    }

    func stop() {
        hideTask?.cancel()
        hudWindow.orderOut(nil)
    }

    deinit {
        hideTask?.cancel()
    }
}

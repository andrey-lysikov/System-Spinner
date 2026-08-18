//  Copyright © (yu) zmlabs, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct OSDView: View {
    @State private var value: OSDValue

    @MainActor
    init() {
        _value = State(initialValue: OSDController.shared.currentValue)
    }

    var body: some View {
        OSDIndicatorView(value: value)
            .padding(48)
            .onReceive(OSDController.shared.valuePublisher) {
                value = $0
            }
    }
}

struct OSDIndicatorView: View {
    let value: OSDValue

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundTint: NSColor {
        colorScheme == .dark
            ? NSColor.black.withAlphaComponent(0.5)
            : NSColor.white.withAlphaComponent(0.5)
    }

    private var foregroundTint: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        let content = HStack(spacing: 16) {
            icon
            VStack(spacing: 4) {
                bar
                scale
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 280, height: 64)

        GlassEffectContainer(tintColor: backgroundTint) { content }
            .frame(width: 280, height: 64)
    }

    @ViewBuilder
    private var icon: some View {
        let image = Image(systemName: value.iconName)
            .font(.system(size: 24, weight: .medium))
            .frame(width: 28)
            .foregroundStyle(foregroundTint.opacity(0.8))

        if Preferences.shared.usesPopUpAnimation {
            image.contentTransition(.symbolEffect(.replace))
        } else {
            image
        }
    }

    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(foregroundTint.opacity(0.25))
                if value.value > 0 {
                    Capsule()
                        .fill(foregroundTint)
                        .frame(width: geometry.size.width * CGFloat(value.value / 100))
                }
            }
        }
        .frame(height: 4)
    }

    private var scale: some View {
        GeometryReader { geometry in
            let steps = max(value.separatorSteps, 1)
            let spacing = max((geometry.size.width - CGFloat(steps + 1)) / CGFloat(steps), 0)

            HStack(spacing: spacing) {
                ForEach(0 ... steps, id: \.self) { index in
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(foregroundTint.opacity(0.8))
                            .frame(width: 1, height: index % 4 == 0 ? 6 : 3)
                    }
                }
            }
        }
        .frame(height: 2)
    }
}

//  Copyright © (yu) zmlabs, AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct OSDView: View {
    @State private var value = OSDValue()

    var body: some View {
        OSDIndicatorView(value: value)
            .padding(48)
            .onAppear {
                value = OSDController.shared.currentValue
            }
            .onReceive(OSDController.shared.valuePublisher.receive(on: RunLoop.main)) {
                value = $0
            }
    }
}

struct OSDIndicatorView: View {
    let value: OSDValue

    /// Расстояние между делениями подобрано под ширину шкалы для каждого шага.
    private static let separatorSpacing: [Int: CGFloat] = [8: 23.25, 16: 11.125, 24: 7.1, 32: 5.1]

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

        GlassEffectContainer { content }
    }

    @ViewBuilder
    private var icon: some View {
        let image = Image(systemName: value.iconName)
            .font(.system(size: 24, weight: .medium))
            .frame(width: 28)
            .foregroundStyle(.primary.opacity(0.8))

        if Preferences.shared.usesPopUpAnimation {
            image.contentTransition(.symbolEffect(.replace))
        } else {
            image
        }
    }

    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.8))
                if value.value > 0 {
                    Capsule()
                        .fill(Color(.secondaryLabelColor))
                        .frame(width: geometry.size.width * CGFloat(value.value / 100))
                }
            }
        }
        .frame(height: 4)
    }

    private var scale: some View {
        HStack(spacing: 0) {
            ForEach(0 ... value.separatorSteps, id: \.self) { index in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(.primary.opacity(0.8))
                        .frame(width: 1, height: index % 4 == 0 ? 6 : 3)
                }
                if index < value.separatorSteps {
                    if let spacing = Self.separatorSpacing[value.separatorSteps] {
                        Spacer().frame(width: spacing)
                    } else {
                        Spacer()
                    }
                }
            }
        }
        .frame(height: 2)
    }
}

//
//  Glass.swift
//  Stossycord
//
//  Created by Alex Badi on 15/10/2025.
//  Source: https://livsycode.com/swiftui/implementing-the-glasseffect-in-swiftui/
//  tysm!
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassedEffect(in shape: some Shape, interactive: Bool = false, clear: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(clear ? (interactive ? .clear.interactive() : .clear) : (interactive ? .regular.interactive() : .regular), in: shape)
        } else {
            self.background {
                shape.glassed()
            }
        }
    }
}

extension View {
    func glassCircleButton(diameter: CGFloat = 44, tint: Color = .white, interactive: Bool = false, clear: Bool = false) -> some View {
        self
            .foregroundStyle(tint)
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .glassedEffect(in: Circle(), interactive: interactive, clear: clear)
            .clipShape(Circle())
    }

    func glassCustomShape(in shape: some Shape, minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center, tint: Color = .white, interactive: Bool = false, clear: Bool = false) -> some View {
        self
            .foregroundStyle(tint)
            .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth, minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment)
            .contentShape(shape)
            .glassedEffect(in: shape, interactive: interactive, clear: clear)
            .clipShape(shape)
    }
}

extension Shape {
    func glassed() -> some View {
        if #available(iOS 17.0, *) {
            AnyView(
                self
                    .fill(.ultraThinMaterial)
                    .fill(
                        .linearGradient(
                            colors: [
                                .primary.opacity(0.08),
                                .primary.opacity(0.05),
                                .primary.opacity(0.01),
                                .clear,
                                .clear,
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .stroke(.primary.opacity(0.2), lineWidth: 0.7)
            )
        } else {
            AnyView(self.fill(.ultraThinMaterial))
        }
    }
}
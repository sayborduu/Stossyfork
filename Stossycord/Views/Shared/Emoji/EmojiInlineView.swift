//
//  EmojiInlineView.swift
//  Stossycord
//
//  Created by Alex Badi on 10/10/2025.
//

import SwiftUI

#if os(iOS)
import Giffy
#endif

struct EmojiInlineView: View {
    let emoji: CustomEmoji
    let lineHeight: CGFloat

    private var displaySize: CGFloat {
        max(12, lineHeight)
    }

    private var targetURL: URL? {
        emoji.url(for: displaySize)
    }

    var body: some View {
        Group {
            if emoji.isAnimated {
                animatedEmoji
            } else {
                staticEmoji
            }
        }
        .frame(width: displaySize, height: displaySize)
        .clipShape(RoundedRectangle(cornerRadius: displaySize * 0.2, style: .continuous))
    }

    @ViewBuilder
    private var staticEmoji: some View {
        CachedAsyncImage(url: targetURL) { image in
            image
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            placeholder
        }
    }

    @ViewBuilder
    private var animatedEmoji: some View {
        #if os(iOS)
        if let url = targetURL {
            AsyncGiffy(url: url) { phase in
                switch phase {
                case .loading:
                    placeholder
                case .error:
                    staticFallback
                case .success(let giffy):
                    giffy
                        .aspectRatio(contentMode: .fit)
                }
            }
        } else {
            staticFallback
        }
        #else
        staticEmoji
        #endif
    }

    private var staticFallback: some View {
        CachedAsyncImage(url: targetURL) { image in
            image
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: displaySize * 0.2, style: .continuous)
            .fill(Color.secondary.opacity(0.2))
    }
}

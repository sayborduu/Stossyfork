//
//  DiscordEmojiImageProvider.swift
//  Stossycord
//
//  Created by Alex Badi on 10/10/2025.
//

import SwiftUI
import MarkdownUI

struct DiscordEmojiImageProvider: ImageProvider {
    let lineHeight: CGFloat

    func makeImage(url: URL?) -> some View {
        Group {
            if let url, url.absoluteString.contains(".stossymoji.") {
                let resolvedURL = decodeStossyURL(from: url) ?? url
                CachedAsyncImage(url: resolvedURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    placeholder
                }
                .frame(width: lineHeight, height: lineHeight)
            } else if let url, let emoji = CustomEmoji(url: url) {
                EmojiInlineView(emoji: emoji, lineHeight: lineHeight)
            } else {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    placeholder
                }
                .frame(width: lineHeight, height: lineHeight)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
    }

    private func decodeStossyURL(from encodedURL: URL) -> URL? {
        let originalString = encodedURL.absoluteString
        let decodedString = originalString.removingPercentEncoding ?? originalString

        if let openParen = decodedString.firstIndex(of: "("),
           let closeParen = decodedString[decodedString.index(after: openParen)...].firstIndex(of: ")") {
            let urlStart = decodedString.index(after: openParen)
            let urlSubstring = decodedString[urlStart..<closeParen]
            let trimmed = urlSubstring.trimmingCharacters(in: .whitespacesAndNewlines)
            if let concreteURL = URL(string: trimmed) {
                return concreteURL
            }
        }

        return URL(string: decodedString)
    }
}

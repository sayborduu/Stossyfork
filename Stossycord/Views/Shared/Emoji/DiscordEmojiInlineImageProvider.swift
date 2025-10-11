//
//  DiscordEmojiInlineImageProvider.swift
//  Stossycord
//
//  Created by Alex Badi on 10/11/2025.
//

import SwiftUI
import MarkdownUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DiscordEmojiInlineImageProvider: InlineImageProvider {
    let lineHeight: CGFloat
    private let defaultProvider = DefaultInlineImageProvider()

    func image(with url: URL, label: String) async throws -> Image {
        if url.absoluteString.contains(".stossymoji.") {
            let resolvedURL = decodeStossyURL(from: url) ?? url
            let urlString = resolvedURL.absoluteString
            if let cachedData = CacheService.shared.getCachedProfilePicture(url: urlString),
               let cachedImage = makeImage(from: cachedData, label: label) {
                return cachedImage
            }
            let (data, _) = try await URLSession.shared.data(from: resolvedURL)
            if let decodedImage = makeImage(from: data, label: label) {
                CacheService.shared.setCachedProfilePicture(data, url: urlString)
                return decodedImage
            }
            return try await defaultProvider.image(with: url, label: label)
        } else if let emoji = CustomEmoji(url: url), let assetURL = emoji.url(for: lineHeight) {
            let urlString = assetURL.absoluteString
            if let cachedData = CacheService.shared.getCachedProfilePicture(url: urlString),
               let cachedImage = makeImage(from: cachedData, label: label) {
                return cachedImage
            }
            let (data, _) = try await URLSession.shared.data(from: assetURL)
            if let decodedImage = makeImage(from: data, label: label) {
                CacheService.shared.setCachedProfilePicture(data, url: urlString)
                return decodedImage
            }
            return try await defaultProvider.image(with: url, label: label)
        } else {
            return try await defaultProvider.image(with: url, label: label)
        }
    }

    private func makeImage(from data: Data, label: String) -> Image? {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        let scaled = scale(image: uiImage)
        return Image(uiImage: scaled).renderingMode(.original)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        let scaled = scale(image: nsImage)
        return Image(nsImage: scaled).renderingMode(.original)
        #else
        return Image(label)
        #endif
    }

#if os(iOS)
    private func scale(image: UIImage) -> UIImage {
        let target = max(lineHeight, 12)
        guard target > 0 else { return image }

        let maxDimension = max(image.size.width, image.size.height)
        guard maxDimension > 0 else { return image }

        let scaleFactor = target / maxDimension
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
#elseif os(macOS)
    private func scale(image: NSImage) -> NSImage {
        let target = max(lineHeight, 12)
        guard target > 0 else { return image }

        let maxDimension = max(image.size.width, image.size.height)
        guard maxDimension > 0 else { return image }

        let scaleFactor = target / maxDimension
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)

        let scaledImage = NSImage(size: newSize)
        scaledImage.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: newSize), from: CGRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        scaledImage.unlockFocus()
        scaledImage.isTemplate = image.isTemplate
        return scaledImage
    }
#endif

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

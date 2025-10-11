//
//  CustomEmojiRenderer.swift
//  Stossycord
//
//  Created by Alex Badi on 10/10/2025.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CustomEmojiRenderer {
    static func markdownString(from content: String) -> String {
        guard !content.isEmpty else { return "" }

        let pattern = try! NSRegularExpression(pattern: "<(a?):([A-Za-z0-9_]+):([0-9]+)>")
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)

        var builder = ""
        var lastIndex = content.startIndex

        pattern.enumerateMatches(in: content, range: nsRange) { result, _, _ in
            guard let result,
                  result.numberOfRanges == 4,
                  let fullRange = Range(result.range(at: 0), in: content),
                  let animatedRange = Range(result.range(at: 1), in: content),
                  let nameRange = Range(result.range(at: 2), in: content),
                  let idRange = Range(result.range(at: 3), in: content) else {
                return
            }

            let prefix = content[lastIndex..<fullRange.lowerBound]
            builder.append(contentsOf: prefix)

            let isAnimated = !content[animatedRange].isEmpty
            let name = String(content[nameRange])
            let identifier = String(content[idRange])
            let emoji = CustomEmoji(name: name, identifier: identifier, isAnimated: isAnimated)

            builder.append(markdown(for: emoji))

            lastIndex = fullRange.upperBound
        }

        builder.append(contentsOf: content[lastIndex...])

        return convertStossyMojiLinks(in: builder)
    }

    private static func markdown(for emoji: CustomEmoji) -> String {
        var components = URLComponents()
        components.scheme = "discord-emoji"
        components.host = emoji.identifier
        var query: [URLQueryItem] = [
            URLQueryItem(name: "name", value: emoji.name)
        ]
        if emoji.isAnimated {
            query.append(URLQueryItem(name: "animated", value: "1"))
        }
        components.queryItems = query

        let urlString = components.url?.absoluteString ?? emoji.identifier
        return "![\(escapeAltText(emoji.name))](\(urlString))"
    }

    private static func escapeAltText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func convertStossyMojiLinks(in text: String) -> String {
        let afterMarkdown = replaceStossyMojiMarkdownLinks(in: text)
        return replaceStossyMojiBareLinks(in: afterMarkdown)
    }

    private static func replaceStossyMojiMarkdownLinks(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "(?<!\\!)\\[(.*?)\\]\\(([^)]+\\.stossymoji\\.[^)]+)\\)", options: []) else {
            return text
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        if matches.isEmpty { return text }

        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            let altRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            guard altRange.location != NSNotFound, urlRange.location != NSNotFound else { continue }

            let altText = nsString.substring(with: altRange)
            let urlText = nsString.substring(with: urlRange)
            let fallbackAlt = fallbackAltText(altText: altText, urlText: urlText)
            let escapedAlt = escapeAltText(fallbackAlt)
            let replacement = "![\(escapedAlt)](\(urlText))"

            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }

        return result
    }

    private static func replaceStossyMojiBareLinks(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "(?<![!\\[])https?://[^\\s)]+\\.stossymoji\\.[^\\s)]+", options: [.caseInsensitive]) else {
            return text
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        if matches.isEmpty { return text }

        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 1 else { continue }
            let urlText = nsString.substring(with: match.range)
            let fallbackAlt = fallbackAltText(altText: "", urlText: urlText)
            let escapedAlt = escapeAltText(fallbackAlt)
            let replacement = "![\(escapedAlt)](\(urlText))"
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }

        return result
    }

    private static func fallbackAltText(altText: String, urlText: String) -> String {
        let trimmedAlt = altText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlt.isEmpty { return trimmedAlt }

        let baseName = baseNameFromURL(urlText)
        if !baseName.isEmpty { return baseName }

        return "emoji"
    }

    private static func baseNameFromURL(_ urlString: String) -> String {
        if let url = URL(string: urlString) {
            let candidate = url.lastPathComponent
            let sanitized = stripStossySuffix(from: candidate)
            if !sanitized.isEmpty { return sanitized }
        }

        if let lastComponent = urlString.split(separator: "/").last {
            let sanitized = stripStossySuffix(from: String(lastComponent))
            if !sanitized.isEmpty { return sanitized }
        }

        return urlString
    }

    private static func stripStossySuffix(from filename: String) -> String {
        if let range = filename.range(of: ".stossymoji.", options: .caseInsensitive) {
            let encrypted = String(filename[..<range.lowerBound])
            let decrypted = EmojiEncryptionContext.decryptIfPossible(encrypted)
            return decrypted
        }
        if let dotIndex = filename.firstIndex(of: ".") {
            return String(filename[..<dotIndex])
        }
        return filename
    }
}

struct CustomEmoji {
    let name: String
    let identifier: String
    let isAnimated: Bool

    init(name: String, identifier: String, isAnimated: Bool) {
        self.name = name
        self.identifier = identifier
        self.isAnimated = isAnimated
    }

    init?(url: URL) {
        guard url.scheme == "discord-emoji" else { return nil }
        if let host = url.host, !host.isEmpty {
            identifier = host
        } else {
            identifier = url.lastPathComponent
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let nameItem = queryItems.first(where: { $0.name == "name" })
        name = nameItem?.value ?? "emoji"
        let animatedItem = queryItems.first(where: { $0.name == "animated" })
        isAnimated = animatedItem?.value == "1" || animatedItem?.value?.lowercased() == "true"
    }

    func url(for _: CGFloat) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "cdn.discordapp.com"
        components.path = "/emojis/\(identifier).webp"

        return components.url
    }
}
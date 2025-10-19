//
//  DiscordEmojiImageProvider.swift
//  Stossycord
//
//  Created by Alex Badi on 10/10/2025.
//

import SwiftUI
import MarkdownUI

// MARK: - Privacy Helper
struct EmojiPrivacyHelper {
    @AppStorage("privacyCustomLoadEmojis") private var privacyCustomLoadEmojis: Bool = false
    @AppStorage("privacyMode") private var privacyModeRaw: String = PrivacyMode.defaultMode.rawValue
    @AppStorage("discordEmojiReplacement") private var discordEmojiReplacement: String = ""
    
    var privacyMode: PrivacyMode { 
        PrivacyMode(rawValue: privacyModeRaw) ?? .standard 
    }
    
    var privacyAllowsCustomEmojis: Bool {
        switch privacyMode {
        case .custom:
            return privacyCustomLoadEmojis
        case .privacy:
            return false
        default:
            return true
        }
    }
    
    func shouldRenderEmojiImages(for content: String) -> Bool {
        privacyAllowsCustomEmojis || containsStossyMoji(content)
    }
    
    func containsStossyMoji(_ content: String) -> Bool {
        content.range(of: ".stossymoji.", options: [.caseInsensitive]) != nil
    }

    private func replacement(for name: String) -> String {
        if !discordEmojiReplacement.isEmpty {
            return discordEmojiReplacement.replacingOccurrences(of: "{n}", with: name)
        } else {
            return ":\(name):"
        }
    }

    func replaceEmojisInContent(_ content: String) -> String {
        let pattern = try! NSRegularExpression(pattern: "<(a?):([A-Za-z0-9_]+):([0-9]+)>")
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        
        var result = ""
        var lastIndex = content.startIndex
        
        pattern.enumerateMatches(in: content, range: nsRange) { match, _, _ in
            guard let match else { return }
            let fullRange = Range(match.range(at: 0), in: content)!
            let nameRange = Range(match.range(at: 2), in: content)!
            let name = String(content[nameRange])
            
            let prefix = content[lastIndex..<fullRange.lowerBound]
            result.append(contentsOf: prefix)
            
            result.append(replacement(for: name))
            
            lastIndex = fullRange.upperBound
        }
        
        result.append(contentsOf: content[lastIndex...])
        
        return replaceStossyLinks(in: result)
    }

    private func replaceStossyLinks(in text: String) -> String {
        var result = text

        if let regex = try? NSRegularExpression(pattern: "(?<!\\!)\\[(.*?)\\]\\(([^)]+\\.stossymoji\\.[^)]+)\\)", options: []) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let altRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                guard altRange.location != NSNotFound, urlRange.location != NSNotFound else { continue }
                let altText = nsString.substring(with: altRange)
                let urlText = nsString.substring(with: urlRange)
                let replacementText = replacement(for: fallbackEmojiName(altText: altText, urlString: urlText))
                if let swiftRange = Range(match.range, in: result) {
                    result.replaceSubrange(swiftRange, with: replacementText)
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: "https?://[^\\s)]+\\.stossymoji\\.[^\\s)]+", options: [.caseInsensitive]) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let urlText = nsString.substring(with: match.range)
                let replacementText = replacement(for: fallbackEmojiName(altText: "", urlString: urlText))
                if let swiftRange = Range(match.range, in: result) {
                    result.replaceSubrange(swiftRange, with: replacementText)
                }
            }
        }

        return result
    }

    private func fallbackEmojiName(altText: String, urlString: String) -> String {
        let trimmedAlt = altText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlt.isEmpty { return trimmedAlt }

        if let url = URL(string: urlString) {
            let candidate = url.lastPathComponent
            return stripStossySuffix(from: candidate)
        }

        if let lastComponent = urlString.split(separator: "/").last {
            return stripStossySuffix(from: String(lastComponent))
        }

        return urlString
    }

    private func stripStossySuffix(from filename: String) -> String {
        if let range = filename.range(of: ".stossymoji.", options: .caseInsensitive) {
            let encrypted = String(filename[..<range.lowerBound])
            return EmojiEncryptionContext.decryptIfPossible(encrypted)
        }
        if let dotIndex = filename.firstIndex(of: ".") {
            return String(filename[..<dotIndex])
        }
        return filename
    }
}

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

//
//  MessageView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation
import MarkdownUI
#if os(iOS)
import Giffy
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MessageView: View {
    let messageData: Message
    @Binding var reply: String?
    @StateObject var webSocketService: WebSocketService
    let isCurrentUser: Bool
    let onProfileTap: (() -> Void)?
    
    @State private var roleColor: Color = .primary

    private var filteredEmbeds: [Embed] {
        (messageData.embeds ?? []).filter { !$0.containsStossyMoji }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isCurrentUser { Spacer(minLength: 60) }
            
            if !isCurrentUser {
                AvatarView(author: messageData.author, onProfileTap: onProfileTap)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                if let replyId = messageData.messageReference?.messageId {
                    ReplyIndicatorView(
                        messageId: replyId,
                        webSocketService: webSocketService,
                        isCurrentUser: isCurrentUser,
                        reply: $reply
                    )
                }
                
                AuthorHeaderView(
                    author: messageData.author,
                    editedTimestamp: messageData.editedtimestamp,
                    roleColor: roleColor,
                    isCurrentUser: isCurrentUser
                )
                
                if !messageData.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MessageContentView(
                        messageData: messageData,
                        isCurrentUser: isCurrentUser
                    )
                }

                if !filteredEmbeds.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredEmbeds, id: \.self) { embed in
                            EmbedCardView(embed: embed, isCurrentUser: isCurrentUser)
                        }
                    }
                }
                
                if let attachments = messageData.attachments, !attachments.isEmpty {
                    HStack {
                        attachmentsView(attachments: attachments)
                    }
                    .padding()
                }

                if let poll = messageData.poll {
                    PollMessageView(
                        message: messageData,
                        webSocketService: webSocketService,
                        poll: poll,
                        isCurrentUser: isCurrentUser
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
            
            if isCurrentUser {
                AvatarView(author: messageData.author, onProfileTap: onProfileTap)
            }
            
            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear { loadRoleColor() }
    }
    
    private func attachmentsView(attachments: [Attachment]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(attachments, id: \.id) { attachment in
                MediaView(url: attachment.url, isCurrentUser: isCurrentUser)
                    .cornerRadius(8)
                    .frame(maxHeight: 300)
            }
        }
    }
    
    private func loadRoleColor() {
        guard let member = webSocketService.currentMembers.first(where: { $0.user.id == messageData.author.authorId }) else {
            return
        }
        
        let roles = member.roles
        
        if let role = roles.compactMap({ roleId in
            webSocketService.currentroles.first { $0.id == roleId && $0.color != 0 }
        }).first {
            roleColor = Color(hex: role.color) ?? .primary
        }
    }
}

struct AvatarView: View {
    let author: Author
    let onProfileTap: (() -> Void)?
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    
    var body: some View {
        if let url = avatarURL {
            let shouldAnimate = author.animated && !disableAnimatedAvatars
            if shouldAnimate {
                #if os(iOS)
                AsyncGiffy(url: url) { phase in
                    switch phase {
                    case .loading:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView().scaleEffect(0.6))
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    case .error:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    case .success(let giffy):
                        giffy
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipped()
                            .clipShape(Circle())
                    }
                }
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
                #else
                AnimatedWebImage(url: url)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .onTapGesture {
                        if !disableProfilePictureTap {
                            onProfileTap?()
                        }
                    }
                #endif
            } else {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
            }
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 36)
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
        }
    }
    
    private var avatarURL: URL? {
        if let avatar = author.avatarHash {
            // If animations are disabled, request PNG — Discord returns the first frame for animated avatars when requested as PNG
            let shouldAnimate = author.animated && !disableAnimatedAvatars
            if shouldAnimate {
                return URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).gif?size=1024&animated=true")
            }
            return URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).png")
        } else {
            return URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")
        }
    }
}

struct AuthorHeaderView: View {
    let author: Author
    let editedTimestamp: String?
    let roleColor: Color
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            if !isCurrentUser {
                Text(author.currentname)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(roleColor)
                
                if editedTimestamp != nil {
                    Text("(edited)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                if editedTimestamp != nil {
                    Text("(edited)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(author.currentname)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(roleColor)
            }
        }
    }
}

struct ReplyIndicatorView: View {
    let messageId: String
    @StateObject var webSocketService: WebSocketService
    let isCurrentUser: Bool
    @Binding var reply: String?
    
    var body: some View {
        HStack(spacing: 6) {
            if !isCurrentUser {
                replyIcon
                replyContent
            } else {
                replyContent
                replyIcon
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
        )
        .onTapGesture { reply = messageId }
    }
    
    private var replyIcon: some View {
        Image(systemName: isCurrentUser ? "arrowshape.turn.up.left" : "arrowshape.turn.up.right")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var replyContent: some View {
        if let referencedMessage = webSocketService.data.first(where: { $0.messageId == messageId }) {
            if !isCurrentUser {
                Text(referencedMessage.author.currentname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(referencedMessage.content)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text(referencedMessage.content)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(referencedMessage.author.currentname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Referenced message unavailable")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct MessageContentView: View {
    let messageData: Message
    let isCurrentUser: Bool
    
    @AppStorage("privacyCustomLoadEmojis") private var privacyCustomLoadEmojis: Bool = false
    @AppStorage("privacyMode") private var privacyModeRaw: String = PrivacyMode.defaultMode.rawValue
    @AppStorage("discordEmojiReplacement") private var discordEmojiReplacement: String = ""
    
    private var privacyMode: PrivacyMode { PrivacyMode(rawValue: privacyModeRaw) ?? .standard }
    private var privacyAllowsCustomEmojis: Bool {
        switch privacyMode {
        case .custom:
            return privacyCustomLoadEmojis
        case .privacy:
            return false
        default:
            return true
        }
    }

    private var containsStossyMoji: Bool {
        messageData.content.range(of: ".stossymoji.", options: [.caseInsensitive]) != nil
    }

    private var shouldRenderEmojiImages: Bool {
        privacyAllowsCustomEmojis || containsStossyMoji
    }
    
    private var markdownContent: String {
        if shouldRenderEmojiImages {
            CustomEmojiRenderer.markdownString(from: messageData.content)
        } else {
            replaceEmojisInContent(messageData.content)
        }
    }

    private static var lineHeight: CGFloat {
        #if os(iOS)
        UIFont.preferredFont(forTextStyle: .body).lineHeight
        #elseif os(macOS)
        NSFont.preferredFont(forTextStyle: .body).boundingRectForFont.size.height
        #else
        18
        #endif
    }

    private func replaceEmojisInContent(_ content: String) -> String {
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
    
    private func replacement(for name: String) -> String {
        if !discordEmojiReplacement.isEmpty {
            return discordEmojiReplacement.replacingOccurrences(of: "%n", with: name)
        } else {
            return ":\(name):"
        }
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

    private var textAlignment: TextAlignment { isCurrentUser ? .trailing : .leading }

    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading) {
            if #available(iOS 19, *) {
                Group {
                    markdownView
                }
                .padding(12)
                .glassEffect(.regular.tint(isCurrentUser ? .blue.opacity(0.6) : .init(uiColor: .darkGray).opacity(0.6)), in: .rect(cornerRadius: 16))
            } else {
                Group {
                    markdownView
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isCurrentUser ? Color.blue : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrentUser ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
            }
        }
    }

    private var markdownView: some View {
        let base = Markdown(markdownContent)
            .markdownTheme(.basic)
            .multilineTextAlignment(textAlignment)
            .lineSpacing(2)
            .foregroundColor(.white)
        
        if shouldRenderEmojiImages {
            return AnyView(
                base
                    .markdownImageProvider(DiscordEmojiImageProvider(lineHeight: MessageContentView.lineHeight))
                    .markdownInlineImageProvider(DiscordEmojiInlineImageProvider(lineHeight: MessageContentView.lineHeight))
            )
        } else {
            return AnyView(base)
        }
    }
}

// MARK: - Extensions
extension Color {
    init?(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}

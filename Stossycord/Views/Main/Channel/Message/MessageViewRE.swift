//
//  MessageViewRE.swift
//  Stossycord
//
//  Created by Alex Badi on 2/10/2025.
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

struct MessageViewRE: View {
    let messageData: Message
    @Binding var reply: String?
    @StateObject var webSocketService: WebSocketService
    let isCurrentUser: Bool
    let onProfileTap: (() -> Void)?
    let onReplyTap: ((Message) -> Void)?
    let isGrouped: Bool
    let allMessages: [Message]
    
    @State private var roleColor: Color = .primary
    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true
    @AppStorage("useSquaredAvatars") private var useSquaredAvatars: Bool = false
    @StateObject private var themeManager = ThemeManager()
    @State private var showTimestampOverlay: Bool = false
    @State private var timestampHideTask: DispatchWorkItem?
    @State private var availableWidth: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var dragMode: DragInteractionMode = .undetermined
    @State private var isMediaInteractionActive = false
    private let replySwipeThreshold: CGFloat = 45

    private var filteredEmbeds: [Embed] {
        (messageData.embeds ?? []).filter { embed in
            if messageData.type == 46, embed.type?.lowercased() == "poll_result" { return false }
            return !embed.containsStossyMoji
        }
    }
    
    private var currentTheme: MessageTheme {
        themeManager.selectedTheme
    }
    
    private var bubbleConfiguration: MessageBubbleVisualConfiguration {
        currentTheme.toVisualConfiguration()
    }
    
    private var maxBubbleWidth: CGFloat? {
        guard availableWidth > 0 else { return nil }
        return availableWidth * 0.9
    }
    
    private var isEmojiOnlyMessage: Bool {
        guard (messageData.attachments?.isEmpty ?? true),
              ((messageData.embeds ?? []).isEmpty || filteredEmbeds.isEmpty) else {
            return false
        }
        return EmojiContentAnalyzer.isEmojiOnly(messageData.content)
    }
    
    private var layoutResolver: MessageLayoutResolver {
        MessageLayoutResolver(isCurrentUser: isCurrentUser, theme: currentTheme)
    }

    private var isTrailingAligned: Bool { layoutResolver.isTrailingAligned }
    private var usesCurrentUserStyle: Bool { layoutResolver.usesCurrentUserStyle }
    
    private var isFirstInGroup: Bool { !isGrouped }
    
    private var isLastInGroup: Bool {
        guard let nextMessage else { return true }
        return !MessageViewRE.shouldGroupMessage(current: nextMessage, previous: messageData)
    }
    
    private var nextMessage: Message? {
        guard let index = allMessages.firstIndex(where: { $0.messageId == messageData.messageId }),
              index + 1 < allMessages.count else {
            return nil
        }
        return allMessages[index + 1]
    }
    
    private var hasTextContent: Bool {
        !messageData.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var timestampText: String? {
        MessageViewRE.formattedTimestamp(from: messageData)
    }

    private var shouldShowTimestamp: Bool { currentTheme.showTimestamps }
    
    private var overlayAlignment: Alignment { layoutResolver.overlayAlignment }
    
    private var verticalAlignment: VerticalAlignment {
        .bottom
    }
    
    private var horizontalSpacing: CGFloat {
        max(8, bubbleConfiguration.horizontalPadding)
    }
    
    private var horizontalPadding: CGFloat {
        if isCurrentUser && isTrailingAligned && !showSelfAvatar {
            return 0
        }
        return bubbleConfiguration.horizontalPadding
    }
    
    private var verticalPadding: CGFloat {
        return isGrouped ? bubbleConfiguration.groupedVerticalPadding : bubbleConfiguration.ungroupedVerticalPadding
    }

    private var contentStackSpacing: CGFloat { 6 }

    private var activeBubbleSide: MessageBubbleVisualConfiguration.Side {
        layoutResolver.activeSide(from: bubbleConfiguration)
    }

    private var avatarSize: CGFloat {
        let base: CGFloat = 36
        let clampedScale = max(bubbleConfiguration.avatarScale, 0.3)
        return max(12, base * clampedScale)
    }
    
    private var isThreadStarterMessage: Bool {
        messageData.type == 18
    }

    private var threadStarterText: String {
        let authorName = messageData.author.currentname
        let trimmedContent = messageData.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentText = trimmedContent.isEmpty ? "Untitled thread" : trimmedContent
        let suffixedContent: String
        if contentText.hasSuffix(".") {
            suffixedContent = contentText
        } else {
            suffixedContent = "\(contentText)."
        }
        return "\(authorName) started a new thread \(suffixedContent)"
    }

    private var pollResultContent: PollResultContent? {
        PollResultContent(message: messageData)
    }

    var body: some View {
        if isThreadStarterMessage {
            threadStarterBody
        } else if let pollContent = pollResultContent {
            PollResultSystemMessageView(content: pollContent)
        } else {
            regularBody
        }
    }

    @ViewBuilder
    private var regularBody: some View {
        ZStack(alignment: overlayAlignment) {
            HStack(alignment: verticalAlignment, spacing: horizontalSpacing) {
                if !isTrailingAligned {
                    avatarColumn(forCurrentUser: isCurrentUser)
                }
                
                let columnAlignment = layoutResolver.columnAlignment
                let frameAlignment = layoutResolver.frameAlignment
                let contentColumn = VStack(alignment: columnAlignment, spacing: contentStackSpacing) {
                    if let replyId = messageData.messageReference?.messageId {
                        ReplyIndicatorView(
                            messageId: replyId,
                            webSocketService: webSocketService,
                            isTrailingAligned: isTrailingAligned,
                            usesCurrentUserStyle: usesCurrentUserStyle,
                            reply: $reply,
                            configuration: bubbleConfiguration
                        )
                    }
                    
                    designHeader()
                    
                    if hasTextContent {
                        MessageContentViewRE(
                            messageData: messageData,
                            usesCurrentUserStyle: usesCurrentUserStyle,
                            isTrailingAligned: isTrailingAligned,
                            configuration: bubbleConfiguration,
                            isEmojiOnly: isEmojiOnlyMessage,
                            editedTimestamp: messageData.editedtimestamp,
                            maxWidth: maxBubbleWidth,
                            trailingTimestamp: shouldShowTimestamp && isLastInGroup ? timestampText : nil
                        )
                    }
                    
                    if !filteredEmbeds.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(filteredEmbeds, id: \.self) { embed in
                                EmbedCardView(embed: embed, isCurrentUser: usesCurrentUserStyle)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isTrailingAligned ? .trailing : .leading)
                    }
                    
                    if let attachments = messageData.attachments, !attachments.isEmpty {
                        attachmentsView(attachments: attachments, maxWidth: maxBubbleWidth)
                            .frame(maxWidth: .infinity, alignment: isTrailingAligned ? .trailing : .leading)
                    }
                    
                    if let poll = messageData.poll {
                        PollMessageView(
                            message: messageData,
                            webSocketService: webSocketService,
                            poll: poll,
                            isCurrentUser: usesCurrentUserStyle
                        )
                    }

                    if shouldShowTimestamp, !hasTextContent, isLastInGroup, let timestampText {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text(timestampText)
                                .font(.caption2)
                                .foregroundStyle(activeBubbleSide.text)
                                .opacity(0.7)
                        }
                    }
                }

                contentColumn
                    .frame(maxWidth: maxBubbleWidth, alignment: frameAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .offset(x: dragOffset)
                
                if isTrailingAligned {
                    avatarColumn(forCurrentUser: isCurrentUser)
                }
            }
            .frame(maxWidth: .infinity, alignment: layoutResolver.frameAlignment)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .simultaneousGesture(swipeGesture)
            
            if shouldShowTimestamp, showTimestampOverlay, let timestampText {
                Text(timestampText)
                    .font(.caption2)
                    .foregroundStyle(activeBubbleSide.text)
                    .opacity(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .background(widthReader)
        .onPreferenceChange(AvailableWidthPreferenceKey.self) { width in
            if width > 0 {
                availableWidth = width
            }
        }
        .onAppear {
            loadRoleColor()
        }
        .onDisappear {
            timestampHideTask?.cancel()
        }
        .onChange(of: themeManager.selectedTheme.id) { _ in
            timestampHideTask?.cancel()
            withAnimation(.easeInOut) {
                showTimestampOverlay = false
            }
        }
        .onChange(of: messageData.messageId) { _ in
            timestampHideTask?.cancel()
            showTimestampOverlay = false
        }
    }

    private var threadStarterBody: some View {
        SystemMessageView(threadStarterText)
    }

    private enum AttachmentRenderItem {
        case mediaCollection([Attachment])
        case single(Attachment)
    }
 
    private enum EmojiContentAnalyzer {
        private static let customEmojiRegex = try! NSRegularExpression(pattern: "<a?:[A-Za-z0-9_]+:[0-9]+>")

        static func isEmojiOnly(_ text: String) -> Bool {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            let replaced = customEmojiRegex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "")
            let hasCustom = customEmojiRegex.firstMatch(in: trimmed, options: [], range: range) != nil
            let filtered = replaced.filter { !$0.isWhitespace && !$0.isNewline }
            var standardFound = false
            for character in filtered {
                if character.isEmojiLike {
                    standardFound = true
                    continue
                }
                return false
            }
            if filtered.isEmpty {
                return hasCustom
            }
            return standardFound
        }
    }

    @ViewBuilder
    private func designHeader() -> some View {
        if isFirstInGroup && !isCurrentUser {
            Text(messageData.author.currentname)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(bubbleConfiguration.otherUser.text)
                .opacity(0.8)
        }
    }
    
    @ViewBuilder
    private func avatarColumn(forCurrentUser: Bool) -> some View {
        if shouldReserveAvatarSpace(forCurrentUser: forCurrentUser) {
            AvatarView(
                author: messageData.author,
                onProfileTap: onProfileTap,
                cornerRadiusOverride: bubbleConfiguration.avatarCornerRadius,
                avatarSize: avatarSize
            )
                .frame(width: avatarSize, height: avatarSize)
                .opacity(shouldShowAvatar(forCurrentUser: forCurrentUser) ? 1 : 0)
                .allowsHitTesting(shouldShowAvatar(forCurrentUser: forCurrentUser))
        }
    }
    
    private func shouldShowAvatar(forCurrentUser: Bool) -> Bool {
        if forCurrentUser {
            return showSelfAvatar && isLastInGroup
        }
        return isLastInGroup
    }
    
    private func shouldReserveAvatarSpace(forCurrentUser: Bool) -> Bool {
        if forCurrentUser {
            return showSelfAvatar
        }
        return true
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 25, coordinateSpace: .local)
            .onChanged { value in
                guard !isMediaInteractionActive else { return }
                handleDragChange(translation: value.translation)
            }
            .onEnded { value in
                if isMediaInteractionActive {
                    dragMode = .undetermined
                    setDragOffsetAnim(0, animated: true)
                    return
                }
                handleSwipe(translation: value.translation)
                setDragOffsetAnim(0, animated: true)
            }
    }

    private func setDragOffsetAnim(_ offset: CGFloat, animated: Bool, duration: Double = 0.3, dampingFraction: Double = 0.7) {
        if animated {
            withAnimation(.spring(response: duration, dampingFraction: dampingFraction)) {
                dragOffset = offset
            }
        } else {
            dragOffset = offset
        }
    }

    private func handleDragChange(translation: CGSize) {
        guard !isMediaInteractionActive else {
            setDragOffsetAnim(0, animated: true)
            return
        }
        let horizontal = translation.width
        let vertical = translation.height

        switch dragMode {
        case .undetermined:
            if abs(horizontal) > 25 && abs(horizontal) > abs(vertical) * 1.5 {
                dragMode = .horizontal
            } else if abs(vertical) > 10 && abs(vertical) >= abs(horizontal) {
                dragMode = .vertical
            }
        case .horizontal:
            break
        case .vertical:
            setDragOffsetAnim(0, animated: true)
            return
        }

        guard dragMode == .horizontal else {
            setDragOffsetAnim(0, animated: true)
            return
        }

        if isTrailingAligned {
            guard horizontal <= 0 else {
                setDragOffsetAnim(0, animated: true)
                return
            }
        } else {
            guard horizontal >= 0 else {
                setDragOffsetAnim(0, animated: true)
                return
            }
        }

        updateDragOffset(translationWidth: horizontal)
    }

    private func updateDragOffset(translationWidth: CGFloat) {
        guard abs(translationWidth) > 8 else {
            setDragOffsetAnim(0, animated: true)
            return
        }

        if isTrailingAligned {
            //dragOffset = max(min(translationWidth, 0), -90)
            setDragOffsetAnim(max(min(translationWidth, 0), -90), animated: true)
        } else {
            //dragOffset = min(max(translationWidth, 0), 90)
            setDragOffsetAnim(min(max(translationWidth, 0), 90), animated: true)
        }
    }

    private func handleSwipe(translation: CGSize) {
        guard !isMediaInteractionActive else {
            dragMode = .undetermined
            return
        }
        let horizontal = translation.width
        let vertical = translation.height

        defer { dragMode = .undetermined }

        guard dragMode == .horizontal else { return }

        if shouldTriggerReply(translationWidth: horizontal) {
            triggerReply()
            return
        }

        guard shouldShowTimestamp else { return }
        let meetsThreshold: Bool
        if isTrailingAligned {
            meetsThreshold = horizontal < -25
        } else {
            meetsThreshold = horizontal > 25
        }
        guard meetsThreshold else { return }
        guard timestampText != nil else { return }
        timestampHideTask?.cancel()
        withAnimation(.easeInOut) {
            showTimestampOverlay = true
        }
        scheduleTimestampHide()
    }

    private func shouldTriggerReply(translationWidth: CGFloat) -> Bool {
        if isTrailingAligned {
            return translationWidth <= -replySwipeThreshold
        } else {
            return translationWidth >= replySwipeThreshold
        }
    }

    private func triggerReply() {
        onReplyTap?(messageData)
    }
    
    private func scheduleTimestampHide() {
        let task = DispatchWorkItem {
            withAnimation(.easeInOut) {
                showTimestampOverlay = false
            }
        }
        timestampHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }
    
    private func attachmentsView(attachments: [Attachment], maxWidth: CGFloat?) -> some View {
        let items = buildAttachmentItems(from: attachments)
        let alignment: HorizontalAlignment = isTrailingAligned ? .trailing : .leading

        return VStack(alignment: alignment, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .mediaCollection(let group):
                    StackedMediaCollectionView(
                        attachments: group,
                        maxWidth: maxWidth,
                        isTrailingAligned: isTrailingAligned
                    )
                    .frame(maxWidth: maxWidth ?? 320, alignment: isTrailingAligned ? .trailing : .leading)
                case .single(let attachment):
                    MediaView(
                        attachment: attachment,
                        isVoiceMessage: shouldRenderVoiceMessage(for: attachment),
                        isCurrentUser: isTrailingAligned,
                        onVoiceScrubChanged: updateMediaInteractionState
                    )
                    .frame(maxWidth: maxWidth ?? 320, alignment: isTrailingAligned ? .trailing : .leading)
                }
            }
        }
    }

    private func updateMediaInteractionState(_ isActive: Bool) {
        isMediaInteractionActive = isActive
    }

    private func shouldRenderVoiceMessage(for attachment: Attachment) -> Bool {
        if let flags = messageData.flags, flags == 8192 {
            return attachment.isLikelyVoiceMessage
        }
        return attachment.isLikelyVoiceMessage
    }

    private func buildAttachmentItems(from attachments: [Attachment]) -> [AttachmentRenderItem] {
        var items: [AttachmentRenderItem] = []
        var mediaBuffer: [Attachment] = []

        func flushBuffer() {
            guard !mediaBuffer.isEmpty else { return }
            if mediaBuffer.count == 1, let single = mediaBuffer.first {
                items.append(.single(single))
            } else {
                items.append(.mediaCollection(mediaBuffer))
            }
            mediaBuffer.removeAll()
        }

        for attachment in attachments {
            if isStackableMedia(attachment) {
                mediaBuffer.append(attachment)
            } else {
                flushBuffer()
                items.append(.single(attachment))
            }
        }

        flushBuffer()
        return items
    }

    private func isStackableMedia(_ attachment: Attachment) -> Bool {
        guard !shouldRenderVoiceMessage(for: attachment) else { return false }

        if let contentType = attachment.contentType?.lowercased() {
            if contentType.hasPrefix("image/") { return true }
            if contentType.hasPrefix("video/") { return true }
        }

        let ext = attachment.inferredFileExtension
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "bmp", "tiff"]
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm", "hevc"]

        return imageExtensions.contains(ext) || videoExtensions.contains(ext)
    }
    
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: AvailableWidthPreferenceKey.self, value: proxy.size.width)
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
    var cornerRadiusOverride: CGFloat? = nil
    var avatarSize: CGFloat = 36
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    @AppStorage("useSquaredAvatars") private var useSquaredAvatars: Bool = false
    
    private var effectiveCornerRadius: CGFloat {
        if let override = cornerRadiusOverride {
            return override
        }
        return useSquaredAvatars ? 8 : 18
    }
    
    private var avatarClipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
    }
    
    var body: some View {
        if let localAsset = localAssetName {
            Image(localAsset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(avatarClipShape)
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
        } else if let url = avatarURL {
            let shouldAnimate = author.animated && !disableAnimatedAvatars
            if shouldAnimate {
                #if os(iOS)
                AsyncGiffy(url: url) { phase in
                    switch phase {
                    case .loading:
                        placeholderShape
                            .overlay(ProgressView().scaleEffect(0.6))
                            .frame(width: avatarSize, height: avatarSize)
                    case .error:
                        placeholderShape
                            .frame(width: avatarSize, height: avatarSize)
                    case .success(let giffy):
                        giffy
                            .aspectRatio(contentMode: .fill)
                            .frame(width: avatarSize, height: avatarSize)
                            .clipped()
                            .clipShape(avatarClipShape)
                    }
                }
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
                #else
                AnimatedWebImage(url: url)
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(avatarClipShape)
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
                    placeholderShape
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(avatarClipShape)
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
            }
        } else {
            placeholderShape
                .frame(width: avatarSize, height: avatarSize)
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
        }
    }
    
    private var placeholderShape: some View {
        avatarClipShape
            .fill(Color.gray.opacity(0.3))
    }
    
    private var avatarURL: URL? {
        guard let avatar = author.avatarHash, !avatar.hasPrefix("asset:") else {
            return URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")
        }

        let shouldAnimate = author.animated && !disableAnimatedAvatars
        if shouldAnimate {
            return URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).gif?size=1024&animated=true")
        }
        return URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).png")
    }

    private var localAssetName: String? {
        guard let avatar = author.avatarHash else { return nil }
        let prefix = "asset:"
        if avatar.hasPrefix(prefix) {
            return String(avatar.dropFirst(prefix.count))
        }
        return nil
    }
}

struct ReplyIndicatorView: View {
    let messageId: String
    @StateObject var webSocketService: WebSocketService
    let isTrailingAligned: Bool
    let usesCurrentUserStyle: Bool
    @Binding var reply: String?
    var configuration: MessageBubbleVisualConfiguration? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            if !isTrailingAligned {
                replyIcon
                replyContent
            } else {
                replyContent
                replyIcon
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundShape)
        .onTapGesture { reply = messageId }
    }
    
    private var replyIcon: some View {
        Image(systemName: isTrailingAligned ? "arrowshape.turn.up.left" : "arrowshape.turn.up.right")
            .font(.system(size: 10))
            .foregroundStyle(accentColor)
    }
    
    @ViewBuilder
    private var replyContent: some View {
        if let referencedMessage = webSocketService.data.first(where: { $0.messageId == messageId }) {
            if !isTrailingAligned {
                Text(referencedMessage.author.currentname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor)
                
                Text(referencedMessage.content)
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
            } else {
                Text(referencedMessage.content)
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                
                Text(referencedMessage.author.currentname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor)
            }
        } else {
            Text("Referenced message unavailable")
                .font(.system(size: 11))
                .foregroundStyle(accentColor)
        }
    }

    private var accentColor: Color {
        if let configuration {
            return usesCurrentUserStyle ? configuration.currentUser.text : configuration.otherUser.text
        }
        return .secondary
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        if let configuration {
            let side = usesCurrentUserStyle ? configuration.currentUser : configuration.otherUser
            RoundedRectangle(cornerRadius: 6)
                .fill(side.background)
                .opacity(0.18)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary)
                .opacity(0.15)
        }
    }
}

private enum DragInteractionMode {
    case undetermined
    case horizontal
    case vertical
}

private struct AvailableWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct MessageBubbleContainer<Content: View>: View {
    let configuration: MessageBubbleVisualConfiguration
    let usesCurrentUserStyle: Bool
    let isTrailingAligned: Bool
    let maxWidth: CGFloat?
    let trailingTimestamp: String?
    private let content: Content

    init(
        configuration: MessageBubbleVisualConfiguration,
        usesCurrentUserStyle: Bool,
        isTrailingAligned: Bool,
        maxWidth: CGFloat?,
        trailingTimestamp: String?,
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.usesCurrentUserStyle = usesCurrentUserStyle
        self.isTrailingAligned = isTrailingAligned
        self.maxWidth = maxWidth
        self.trailingTimestamp = trailingTimestamp
        self.content = content()
    }

    var body: some View {
        let side = usesCurrentUserStyle ? configuration.currentUser : configuration.otherUser
        let padded = content
            .padding(configuration.padding.edgeInsets)
        let timestampAlignment: Alignment = isTrailingAligned ? .bottomTrailing : .bottomLeading

        Group {
            #if os(iOS)
            if #available(iOS 19, *), configuration.glassEffect {
                padded
                    .glassEffect(
                        .regular.tint(side.background.opacity(0.6)),
                        in: .rect(cornerRadius: configuration.cornerRadius)
                    )
                    .overlay(strokeOverlay(for: side))
                    .overlay(alignment: timestampAlignment) { timestampView }
            } else {
                padded
                    .background(
                        RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                            .fill(side.background)
                    )
                    .overlay(strokeOverlay(for: side))
                    .overlay(alignment: timestampAlignment) { timestampView }
            }
            #else
            padded
                .background(
                    RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                        .fill(side.background)
                )
                .overlay(strokeOverlay(for: side))
                .overlay(alignment: timestampAlignment) { timestampView }
            #endif
        }
        .frame(maxWidth: maxWidth, alignment: isTrailingAligned ? .trailing : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func strokeOverlay(for side: MessageBubbleVisualConfiguration.Side) -> some View {
        if configuration.strokeWidth > 0 {
            RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                .stroke(side.stroke ?? Color.clear, lineWidth: configuration.strokeWidth)
        }
    }

    @ViewBuilder
    private var timestampView: some View {
        if let trailingTimestamp {
            Text(trailingTimestamp)
                .font(.system(size: 10))
                .foregroundColor(activeSide.text.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
        }
    }

    private var activeSide: MessageBubbleVisualConfiguration.Side {
        usesCurrentUserStyle ? configuration.currentUser : configuration.otherUser
    }
}

private struct StackedMediaCollectionView: View {
    let attachments: [Attachment]
    let maxWidth: CGFloat?
    let isTrailingAligned: Bool

    @State private var selection = 0

    private var clampedWidth: CGFloat {
        min(max(maxWidth ?? 260, 200), 360)
    }

    private var baseHeight: CGFloat {
        clampedWidth * 0.72
    }

    var body: some View {
        let width = clampedWidth
        let height = baseHeight
        let direction: CGFloat = isTrailingAligned ? -1 : 1

        ZStack {
            backgroundStack(width: width, height: height, direction: direction)

            TabView(selection: $selection) {
                ForEach(Array(attachments.enumerated()), id: \.offset) { index, attachment in
                    MediaView(
                        attachment: attachment,
                        isVoiceMessage: false,
                        isCurrentUser: isTrailingAligned
                    )
                    .frame(maxWidth: width, maxHeight: height)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .overlay(alignment: isTrailingAligned ? .topTrailing : .topLeading) {
            if attachments.count > 1 {
                mediaCountBadge
            }
        }
    }

    private func backgroundStack(width: CGFloat, height: CGFloat, direction: CGFloat) -> some View {
        let count = max(min(attachments.count - 1, 2), 0)
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let offsetIndex = CGFloat(index + 1)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.05 + 0.04 * offsetIndex))
                    .frame(
                        width: width - offsetIndex * 8,
                        height: height - offsetIndex * 6
                    )
                    .rotationEffect(.degrees(Double(offsetIndex) * 3 * Double(direction)))
                    .offset(x: offsetIndex * 6 * direction, y: offsetIndex * 8)
            }
        }
    }

    private var mediaCountBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.on.rectangle")
            Text("\(attachments.count)")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private extension Attachment {
    var inferredFileExtension: String {
        if let filename = filename?.lowercased(), let ext = filename.split(separator: ".").last {
            return String(ext)
        }
        if let urlExtension = URL(string: url)?.pathExtension.lowercased(), !urlExtension.isEmpty {
            return urlExtension
        }
        return ""
    }
}

struct MessageContentViewRE: View {
    let messageData: Message
    let usesCurrentUserStyle: Bool
    let isTrailingAligned: Bool
    let configuration: MessageBubbleVisualConfiguration
    let isEmojiOnly: Bool
    let editedTimestamp: String?
    let maxWidth: CGFloat?
    let trailingTimestamp: String?

    @AppStorage("discordEmojiReplacement") private var discordEmojiReplacement: String = ""
    
    private let privacyHelper = EmojiPrivacyHelper()
    
    private var shouldRenderEmojiImages: Bool {
        privacyHelper.shouldRenderEmojiImages(for: messageData.content)
    }

    private var isEdited: Bool { editedTimestamp != nil }
    private var currentSide: MessageBubbleVisualConfiguration.Side {
        usesCurrentUserStyle ? configuration.currentUser : configuration.otherUser
    }
    private var textAlignment: TextAlignment {
        if isEmojiOnly { return .center }
        return isTrailingAligned ? .trailing : .leading
    }
    private var contentAlignment: HorizontalAlignment {
        if isEmojiOnly { return .center }
        return isTrailingAligned ? .trailing : .leading
    }
    private var contentSpacing: CGFloat { isEmojiOnly ? 0 : 2 }
    private var lineSpacing: CGFloat { isEmojiOnly ? 0 : 2 }
    private var baseFont: Font { .system(size: isEmojiOnly ? 34 : 15) }
    private var emojiScale: CGFloat { isEmojiOnly ? 1.45 : 1.0 }

    private var markdownContent: String {
        if shouldRenderEmojiImages {
            CustomEmojiRenderer.markdownString(from: messageData.content)
        } else {
            replaceEmojisInContent(messageData.content)
        }
    }

    private var resolvedLineHeight: CGFloat {
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
            return discordEmojiReplacement
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

    var body: some View {
        MessageBubbleContainer(
            configuration: configuration,
            usesCurrentUserStyle: usesCurrentUserStyle,
            isTrailingAligned: isTrailingAligned,
            maxWidth: maxWidth,
            trailingTimestamp: trailingTimestamp
        ) {
            VStack(alignment: contentAlignment, spacing: contentSpacing) {
                messageContent
                    .foregroundColor(currentSide.text)
                    .lineSpacing(lineSpacing)
            }
        }
        .overlay(alignment: isTrailingAligned ? .bottomTrailing : .bottomLeading) {
            if isEdited {
                Text("(edited)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        let base = Markdown(markdownContent)
            .markdownTheme(.basic)
            .multilineTextAlignment(textAlignment)
            .lineSpacing(lineSpacing)
            .foregroundColor(currentSide.text)
        
        if shouldRenderEmojiImages {
            base
                .markdownImageProvider(DiscordEmojiImageProvider(lineHeight: resolvedLineHeight))
                .markdownInlineImageProvider(DiscordEmojiInlineImageProvider(lineHeight: resolvedLineHeight))
                .font(baseFont)
                .scaleEffect(emojiScale, anchor: .center)
        } else {
            base
                .font(baseFont)
                .scaleEffect(emojiScale, anchor: .center)
        }
    }
    
}

private extension Character {
    var isEmojiLike: Bool {
        var containsEmojiScalar = false
        for scalar in unicodeScalars {
            if scalar.properties.isEmojiPresentation || scalar.properties.isEmoji || scalar.properties.isEmojiModifier {
                containsEmojiScalar = true
                continue
            }
            switch scalar.value {
            case 0x200D, 0xFE0F:
                continue
            case 0x23, 0x2A, 0x30...0x39:
                containsEmojiScalar = true
                continue
            default:
                return false
            }
        }
        return containsEmojiScalar
    }
}

extension MessageViewRE {
    static func shouldGroupMessage(current: Message, previous: Message?) -> Bool {
        guard let previous = previous else { return false }
        
        if current.author.authorId != previous.author.authorId {
            return false
        }
        
        let currentTimestamp = MessageViewRE.extractTimestamp(from: current.messageId)
        let previousTimestamp = MessageViewRE.extractTimestamp(from: previous.messageId)
        
        let timeDifference = abs(currentTimestamp - previousTimestamp)
        let thirtyMinutesInSeconds: TimeInterval = 30 * 60
        
        return timeDifference <= thirtyMinutesInSeconds
    }
    
    static func extractTimestamp(from messageId: String) -> TimeInterval {
        guard let id = UInt64(messageId) else { return 0 }
        let discordEpoch: UInt64 = 1420070400000
        let timestamp = (id >> 22) + discordEpoch
        return TimeInterval(timestamp / 1000)
    }
    
    private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static func formattedTimestamp(from message: Message) -> String? {
        guard let timestampString = message.timestamp else { return nil }
        if let date = isoFormatterWithFractionalSeconds.date(from: timestampString) ?? isoFormatter.date(from: timestampString) {
            return timeFormatter.string(from: date)
        }
        return nil
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

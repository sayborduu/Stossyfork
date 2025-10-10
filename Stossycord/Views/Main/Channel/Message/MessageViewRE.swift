//
//  MessageViewRE.swift
//  Stossycord
//
//  Created by AI Assistant on 2/10/2025.
//

import SwiftUI
import Foundation
#if os(iOS)
import Giffy
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
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = MessageBubbleStyle.imessage.rawValue
    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true
    @AppStorage(DesignSettingsKeys.customMessageBubbleJSON) private var customBubbleJSON: String = ""
    @State private var showTimestampOverlay: Bool = false
    @State private var timestampHideTask: DispatchWorkItem?
    @State private var availableWidth: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var dragMode: DragInteractionMode = .undetermined
    private let replySwipeThreshold: CGFloat = 45
    
    private var messageStyle: MessageBubbleStyle {
    MessageBubbleStyle(rawValue: messageStyleRawValue) ?? .imessage
    }
    
    private var bubbleConfiguration: MessageBubbleVisualConfiguration {
        MessageBubbleVisualConfiguration.resolve(style: messageStyle, customJSON: customBubbleJSON)
    }
    
    private var maxBubbleWidth: CGFloat? {
        guard availableWidth > 0 else { return nil }
        return availableWidth * 0.9
    }
    
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

    private var shouldShowTimestamp: Bool { false }
    
    private var overlayAlignment: Alignment {
        Alignment(
            horizontal: isCurrentUser ? .leading : .trailing,
            vertical: .center
        )
    }
    
    private var verticalAlignment: VerticalAlignment {
        messageStyle == .default ? .top : .bottom
    }
    
    private var horizontalSpacing: CGFloat {
        messageStyle == .default ? 8 : 12
    }
    
    private var horizontalPadding: CGFloat {
        if isCurrentUser && !showSelfAvatar && messageStyle != .default {
            return 0
        }
        return bubbleConfiguration.horizontalPadding
    }
    
    private var verticalPadding: CGFloat {
        return isGrouped ? bubbleConfiguration.groupedVerticalPadding : bubbleConfiguration.ungroupedVerticalPadding
    }

    private var contentStackSpacing: CGFloat { 6 }
    
    var body: some View {
        ZStack(alignment: overlayAlignment) {
            HStack(alignment: verticalAlignment, spacing: horizontalSpacing) {
                if !isCurrentUser {
                    avatarColumn(forCurrentUser: false)
                }
                
                let columnAlignment = isCurrentUser ? HorizontalAlignment.trailing : .leading
                let frameAlignment: Alignment = isCurrentUser ? .trailing : .leading
                let contentColumn = VStack(alignment: columnAlignment, spacing: contentStackSpacing) {
                    if let replyId = messageData.messageReference?.messageId {
                        ReplyIndicatorView(
                            messageId: replyId,
                            webSocketService: webSocketService,
                            isCurrentUser: isCurrentUser,
                            reply: $reply
                        )
                    }
                    
                    designHeader()
                    
                    if hasTextContent {
                        MessageContentViewRE(
                            messageData: messageData,
                            isCurrentUser: isCurrentUser,
                            style: messageStyle,
                            configuration: bubbleConfiguration,
                            editedTimestamp: messageData.editedtimestamp,
                            maxWidth: maxBubbleWidth,
                            trailingTimestamp: shouldShowTimestamp && isLastInGroup ? timestampText : nil
                        )
                    }
                    
                    if let embeds = messageData.embeds, !embeds.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(embeds, id: \.self) { embed in
                                EmbedCardView(embed: embed, isCurrentUser: isCurrentUser)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                    }
                    
                    if let attachments = messageData.attachments, !attachments.isEmpty {
                        HStack {
                            attachmentsView(attachments: attachments)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                    }
                    
                    if let poll = messageData.poll {
                        PollMessageView(
                            message: messageData,
                            webSocketService: webSocketService,
                            poll: poll,
                            isCurrentUser: isCurrentUser
                        )
                    }

                    if shouldShowTimestamp, !hasTextContent, isLastInGroup, let timestampText {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text(timestampText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                contentColumn
                    .frame(maxWidth: maxBubbleWidth, alignment: frameAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .offset(x: dragOffset)
                
                if isCurrentUser {
                    avatarColumn(forCurrentUser: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .simultaneousGesture(swipeGesture)
            
            if shouldShowTimestamp, messageStyle == .imessage, showTimestampOverlay, let timestampText {
                Text(timestampText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
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
            ensureValidMessageStyle()
            loadRoleColor()
        }
        .onDisappear {
            timestampHideTask?.cancel()
        }
        .onChange(of: messageStyleRawValue) { _ in
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
    
    @ViewBuilder
    private func designHeader() -> some View {
        switch messageStyle {
        case .default, .custom:
            if isFirstInGroup {
                AuthorHeaderView(
                    author: messageData.author,
                    editedTimestamp: messageData.editedtimestamp,
                    roleColor: roleColor,
                    isCurrentUser: isCurrentUser
                )
            }
        case .imessage:
            if isFirstInGroup && !isCurrentUser {
                Text(messageData.author.currentname)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func avatarColumn(forCurrentUser: Bool) -> some View {
        switch messageStyle {
        case .default:
            if shouldShowAvatar(forCurrentUser: forCurrentUser) {
                AvatarView(author: messageData.author, onProfileTap: onProfileTap)
            }
        default:
            if shouldReserveAvatarSpace(forCurrentUser: forCurrentUser) {
                AvatarView(author: messageData.author, onProfileTap: onProfileTap)
                    .frame(width: 36, height: 36)
                    .opacity(shouldShowAvatar(forCurrentUser: forCurrentUser) ? 1 : 0)
                    .allowsHitTesting(shouldShowAvatar(forCurrentUser: forCurrentUser))
            }
        }
    }
    
    private func shouldShowAvatar(forCurrentUser: Bool) -> Bool {
        switch messageStyle {
        case .default, .custom:
            if forCurrentUser {
                return !isGrouped && showSelfAvatar
            }
            return !isGrouped
        case .imessage:
            if forCurrentUser {
                return showSelfAvatar && isLastInGroup
            }
            return isLastInGroup
        }
    }
    
    private func shouldReserveAvatarSpace(forCurrentUser: Bool) -> Bool {
        switch messageStyle {
        case .default, .custom:
            return shouldShowAvatar(forCurrentUser: forCurrentUser)
        case .imessage:
            if forCurrentUser {
                return showSelfAvatar
            }
            return true
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 25, coordinateSpace: .local)
            .onChanged { value in
                handleDragChange(translation: value.translation)
            }
            .onEnded { value in
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

        if isCurrentUser {
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

        if isCurrentUser {
            //dragOffset = max(min(translationWidth, 0), -90)
            setDragOffsetAnim(max(min(translationWidth, 0), -90), animated: true)
        } else {
            //dragOffset = min(max(translationWidth, 0), 90)
            setDragOffsetAnim(min(max(translationWidth, 0), 90), animated: true)
        }
    }

    private func handleSwipe(translation: CGSize) {
        let horizontal = translation.width
        let vertical = translation.height

        defer { dragMode = .undetermined }

        guard dragMode == .horizontal else { return }

        if shouldTriggerReply(translationWidth: horizontal) {
            triggerReply()
            return
        }

    guard shouldShowTimestamp else { return }
    guard messageStyle == .imessage else { return }
        guard horizontal < -25 else { return }
        guard timestampText != nil else { return }
        timestampHideTask?.cancel()
        withAnimation(.easeInOut) {
            showTimestampOverlay = true
        }
        scheduleTimestampHide()
    }

    private func shouldTriggerReply(translationWidth: CGFloat) -> Bool {
        if isCurrentUser {
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
    
    private func attachmentsView(attachments: [Attachment]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(attachments, id: \.id) { attachment in
                MediaView(url: attachment.url, isCurrentUser: isCurrentUser)
                    .cornerRadius(8)
                    .frame(maxHeight: 300)
            }
        }
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

    private func ensureValidMessageStyle() {
        guard let style = MessageBubbleStyle(rawValue: messageStyleRawValue) else {
            messageStyleRawValue = MessageBubbleStyle.imessage.rawValue
            return
        }

        if style == .default {
            messageStyleRawValue = MessageBubbleStyle.imessage.rawValue
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

struct MessageContentViewRE: View {
    let messageData: Message
    let isCurrentUser: Bool
    let style: MessageBubbleStyle
    let configuration: MessageBubbleVisualConfiguration
    let editedTimestamp: String?
    let maxWidth: CGFloat?
    let trailingTimestamp: String?

    private var isEdited: Bool { editedTimestamp != nil }
    private var currentSide: MessageBubbleVisualConfiguration.Side {
        isCurrentUser ? configuration.currentUser : configuration.otherUser
    }
    private var textAlignment: TextAlignment { isCurrentUser ? .trailing : .leading }
    private var lineSpacing: CGFloat { 2 }

    private var messageAttributedString: AttributedString {
        (try? AttributedString(markdown: messageData.content, options: MessageContentViewRE.markdownOptions))
            ?? AttributedString(messageData.content)
    }

    private static let markdownOptions = AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: true, interpretedSyntax: .full)

    @ViewBuilder
    private var timestampBadge: some View {
        if let trailingTimestamp {
            Text(trailingTimestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
        }
    }
    
    var body: some View {
        bubbleContainer {
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                messageContent
                    .foregroundColor(currentSide.text)
                    .lineSpacing(lineSpacing)
                
                if style != .default && isEdited {
                    Text("(edited)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                }
            }
        }
    .frame(maxWidth: maxWidth, alignment: isCurrentUser ? .trailing : .leading)
    .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private var messageContent: some View {
        Text(messageAttributedString)
            .multilineTextAlignment(textAlignment)
    }
    
    @ViewBuilder
    private func bubbleContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let side = currentSide
        let padded = content()
            .padding(configuration.padding.edgeInsets)
        #if os(iOS)
        if #available(iOS 19, *), configuration.glassEffect {
            padded
                .glassEffect(
                    .regular.tint(side.background.opacity(0.6)),
                    in: .rect(cornerRadius: configuration.cornerRadius)
                )
                .overlay(strokeOverlay(for: side))
                .overlay(alignment: .bottomTrailing) { timestampBadge }
        } else {
            padded
                .background(
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .fill(side.background)
                )
                .overlay(strokeOverlay(for: side))
                .overlay(alignment: .bottomTrailing) { timestampBadge }
        }
        #else
        padded
            .background(
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(side.background)
            )
            .overlay(strokeOverlay(for: side))
            .overlay(alignment: .bottomTrailing) { timestampBadge }
        #endif
    }
    
    @ViewBuilder
    private func strokeOverlay(for side: MessageBubbleVisualConfiguration.Side) -> some View {
        if configuration.strokeWidth > 0 {
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(side.stroke ?? Color.clear, lineWidth: configuration.strokeWidth)
        }
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
//
//  ThemePreviewView.swift
//  Stossycord
//
//  Created by Alex Badi on 18/10/2025.
//

import SwiftUI
import Foundation

struct ThemePreviewView: View {
    let theme: MessageTheme
    @ObservedObject var websocketService: WebSocketService

    @State private var availableWidth: CGFloat = 0

    private var configuration: MessageBubbleVisualConfiguration {
        theme.toVisualConfiguration()
    }

    private var backgroundOpacity: Double {
        let value = Double(theme.chatBackgroundOpacity)
        return min(max(value, 0), 1)
    }

    private var containerCornerRadius: CGFloat { max(theme.cornerRadius + 8, 12) }

    private var containerBackground: Color {
        theme.chatBackgroundColorValue ?? fallbackBackground
    }

    private var maxBubbleWidth: CGFloat? {
        guard availableWidth > 0 else { return 320 }
        return availableWidth * 0.9
    }

    #if os(macOS)
    private var fallbackBackground: Color { Color(nsColor: .windowBackgroundColor) }
    #else
    private var fallbackBackground: Color { Color(.systemGroupedBackground) }
    #endif

    var body: some View {
        VStack(spacing: 0) {
            ForEach(previewMessages) { item in
                ThemePreviewMessageRow(
                    item: item,
                    theme: theme,
                    configuration: configuration,
                    maxBubbleWidth: maxBubbleWidth
                )
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                .fill(containerBackground)
                .opacity(backgroundOpacity)
        )
        .background(widthReader)
        .onPreferenceChange(ThemePreviewWidthPreferenceKey.self) { width in
            if width > 0 {
                availableWidth = width
            }
        }
        .animation(.easeInOut(duration: 0.3), value: theme)
        .animation(.easeInOut(duration: 0.3), value: containerBackground)
    }

    private var previewMessages: [ThemePreviewMessage] {
        let stossyAuthor = Author(
            username: "stossy11",
            avatarHash: "asset:StossyAvatar",
            authorId: "666809671134347294/preview",
            nick: nil,
            globalName: "stossy11",
            bio: nil
        )

        let sayborduuAuthor = Author(
            username: "sayborduu",
            avatarHash: "asset:SayborduuAvatar",
            authorId: "978750269481418792/preview",
            nick: nil,
            globalName: "alex!",
            bio: nil
        )

        let currentUser = websocketService.currentUser
        let currentAuthor = Author(
            username: currentUser.username,
            avatarHash: currentUser.avatar,
            authorId: currentUser.id,
            nick: nil,
            globalName: currentUser.globalName,
            bio: nil
        )

        let messageOne = ThemePreviewMessage(
            message: Message(
                channelId: "preview",
                content: "Hey! This is what your theme looks like :O",
                messageId: "preview-1",
                editedtimestamp: nil,
                timestamp: ThemePreviewView.isoTimestamp(minutesAgo: 3),
                type: 0,
                guildId: nil,
                author: stossyAuthor,
                messageReference: nil,
                attachments: nil,
                embeds: nil,
                poll: nil,
                channelType: nil,
                flags: nil
            ),
            isCurrentUser: false,
            isFirstInGroup: true,
            isLastInGroup: true
        )

        let messageTwo = ThemePreviewMessage(
            message: Message(
                channelId: "preview",
                content: "oh btw, im not adding compact mode easter egg yk??",
                messageId: "preview-2",
                editedtimestamp: nil,
                timestamp: ThemePreviewView.isoTimestamp(minutesAgo: 2),
                type: 0,
                guildId: nil,
                author: sayborduuAuthor,
                messageReference: nil,
                attachments: nil,
                embeds: nil,
                poll: nil,
                channelType: nil,
                flags: nil
            ),
            isCurrentUser: false,
            isFirstInGroup: true,
            isLastInGroup: true
        )

        let messageThree = ThemePreviewMessage(
            message: Message(
                channelId: "preview",
                content: "oh my messages are on my side too!",
                messageId: "preview-3",
                editedtimestamp: nil,
                timestamp: ThemePreviewView.isoTimestamp(minutesAgo: 1),
                type: 0,
                guildId: nil,
                author: currentAuthor,
                messageReference: nil,
                attachments: nil,
                embeds: nil,
                poll: nil,
                channelType: nil,
                flags: nil
            ),
            isCurrentUser: true,
            isFirstInGroup: true,
            isLastInGroup: true
        )

        return [messageOne, messageTwo, messageThree]
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: ThemePreviewWidthPreferenceKey.self, value: proxy.size.width)
        }
    }

    private static func isoTimestamp(minutesAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .minute, value: -minutesAgo, to: Date()) ?? Date()
        return isoFormatter.string(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct ThemePreviewMessageRow: View {
    let item: ThemePreviewMessage
    let theme: MessageTheme
    let configuration: MessageBubbleVisualConfiguration
    let maxBubbleWidth: CGFloat?

    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true

    private var resolver: MessageLayoutResolver {
        MessageLayoutResolver(isCurrentUser: item.isCurrentUser, theme: theme)
    }

    private var horizontalSpacing: CGFloat {
        max(8, configuration.horizontalPadding)
    }

    private var verticalPadding: CGFloat {
        item.isFirstInGroup ? configuration.ungroupedVerticalPadding : configuration.groupedVerticalPadding
    }

    private var timestampText: String? {
        MessageViewRE.formattedTimestamp(from: item.message)
    }

    private var shouldShowTrailingTimestamp: Bool {
        theme.showTimestamps && item.isLastInGroup && timestampText != nil
    }

    private var avatarSize: CGFloat {
        let base: CGFloat = 36
        return max(12, base * max(configuration.avatarScale, 0.3))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: horizontalSpacing) {
            if !resolver.isTrailingAligned {
                avatarColumn
            }

            VStack(alignment: resolver.columnAlignment, spacing: 6) {
                if item.isFirstInGroup && !item.isCurrentUser {
                    Text(item.message.author.currentname)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(configuration.otherUser.text)
                        .opacity(0.8)
                }

                MessageContentViewRE(
                    messageData: item.message,
                    usesCurrentUserStyle: resolver.usesCurrentUserStyle,
                    isTrailingAligned: resolver.isTrailingAligned,
                    configuration: configuration,
                    isEmojiOnly: false,
                    editedTimestamp: item.message.editedtimestamp,
                    maxWidth: maxBubbleWidth,
                    trailingTimestamp: shouldShowTrailingTimestamp ? timestampText : nil
                )
            }
            .frame(maxWidth: maxBubbleWidth, alignment: resolver.frameAlignment)
            .frame(maxWidth: .infinity, alignment: resolver.frameAlignment)

            if resolver.isTrailingAligned {
                avatarColumn
            }
        }
        .padding(.horizontal, configuration.horizontalPadding)
        .padding(.vertical, verticalPadding)
    }

    private var avatarColumn: some View {
        Group {
            if shouldReserveAvatarSpace {
                AvatarView(
                    author: item.message.author,
                    onProfileTap: nil,
                    cornerRadiusOverride: configuration.avatarCornerRadius,
                    avatarSize: avatarSize
                )
                .frame(width: avatarSize, height: avatarSize)
                .opacity(shouldShowAvatar ? 1 : 0)
                .allowsHitTesting(false)
            }
        }
    }

    private var shouldShowAvatar: Bool {
        if item.isCurrentUser {
            return showSelfAvatar && item.isLastInGroup
        }
        return item.isLastInGroup
    }

    private var shouldReserveAvatarSpace: Bool {
        if item.isCurrentUser {
            return showSelfAvatar
        }
        return true
    }
}

private struct ThemePreviewMessage: Identifiable {
    let id = UUID()
    let message: Message
    let isCurrentUser: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
}

private struct ThemePreviewWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

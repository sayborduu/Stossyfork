//
//  Message.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct MessageType: Identifiable {
    let id: Int
    let name: String
    let description: String
    let deletable: Bool
}

let messageTypes: [MessageType] = [
    .init(id: 0, name: "DEFAULT", description: "A default message (see below)", deletable: true),
    .init(id: 1, name: "RECIPIENT_ADD", description: "A message sent when a user is added to a group DM or thread", deletable: false),
    .init(id: 2, name: "RECIPIENT_REMOVE", description: "A message sent when a user is removed from a group DM or thread", deletable: false),
    .init(id: 3, name: "CALL", description: "A message sent when a user creates a call in a private channel", deletable: false),
    .init(id: 4, name: "CHANNEL_NAME_CHANGE", description: "A message sent when a group DM or thread's name is changed", deletable: false),
    .init(id: 5, name: "CHANNEL_ICON_CHANGE", description: "A message sent when a group DM's icon is changed", deletable: false),
    .init(id: 6, name: "CHANNEL_PINNED_MESSAGE", description: "A message sent when a message is pinned in a channel", deletable: true),
    .init(id: 7, name: "USER_JOIN", description: "A message sent when a user joins a guild", deletable: true),
    .init(id: 8, name: "PREMIUM_GUILD_SUBSCRIPTION", description: "A message sent when a user subscribes to (boosts) a guild", deletable: true),
    .init(id: 9, name: "PREMIUM_GUILD_SUBSCRIPTION_TIER_1", description: "A message sent when a user boosts a guild to tier 1", deletable: true),
    .init(id: 10, name: "PREMIUM_GUILD_SUBSCRIPTION_TIER_2", description: "A message sent when a user boosts a guild to tier 2", deletable: true),
    .init(id: 11, name: "PREMIUM_GUILD_SUBSCRIPTION_TIER_3", description: "A message sent when a user boosts a guild to tier 3", deletable: true),
    .init(id: 12, name: "CHANNEL_FOLLOW_ADD", description: "A message sent when a news channel is followed", deletable: true),
    .init(id: 13, name: "GUILD_STREAM", description: "A message sent when a user starts streaming in a guild", deletable: true),
    .init(id: 14, name: "GUILD_DISCOVERY_DISQUALIFIED", description: "A message sent when a guild is disqualified from discovery", deletable: true),
    .init(id: 15, name: "GUILD_DISCOVERY_REQUALIFIED", description: "A message sent when a guild requalifies for discovery", deletable: true),
    .init(id: 16, name: "GUILD_DISCOVERY_GRACE_PERIOD_INITIAL_WARNING", description: "A message sent when a guild has failed discovery requirements for a week", deletable: true),
    .init(id: 17, name: "GUILD_DISCOVERY_GRACE_PERIOD_FINAL_WARNING", description: "A message sent when a guild has failed discovery requirements for 3 weeks", deletable: true),
    .init(id: 18, name: "THREAD_CREATED", description: "A message sent when a thread is created", deletable: true),
    .init(id: 19, name: "REPLY", description: "A message sent when a user replies to a message", deletable: true),
    .init(id: 20, name: "CHAT_INPUT_COMMAND", description: "A message sent when a user uses a slash command", deletable: true),
    .init(id: 21, name: "THREAD_STARTER_MESSAGE", description: "A message sent when a thread starter message is added to a thread", deletable: false),
    .init(id: 22, name: "GUILD_INVITE_REMINDER", description: "A message sent to remind users to invite friends to a guild", deletable: true),
    .init(id: 23, name: "CONTEXT_MENU_COMMAND", description: "A message sent when a user uses a context menu command", deletable: true),
    .init(id: 24, name: "AUTO_MODERATION_ACTION", description: "A message sent when auto moderation takes an action", deletable: true),
    .init(id: 25, name: "ROLE_SUBSCRIPTION_PURCHASE", description: "A message sent when a user purchases or renews a role subscription", deletable: true),
    .init(id: 26, name: "INTERACTION_PREMIUM_UPSELL", description: "A message sent when a user is upsold to a premium interaction", deletable: true),
    .init(id: 27, name: "STAGE_START", description: "A message sent when a stage channel starts", deletable: true),
    .init(id: 28, name: "STAGE_END", description: "A message sent when a stage channel ends", deletable: true),
    .init(id: 29, name: "STAGE_SPEAKER", description: "A message sent when a user starts speaking in a stage channel", deletable: true),
    .init(id: 30, name: "STAGE_RAISE_HAND", description: "A message sent when a user raises their hand in a stage channel", deletable: true),
    .init(id: 31, name: "STAGE_TOPIC", description: "A message sent when a stage channel's topic is changed", deletable: true),
    .init(id: 32, name: "GUILD_APPLICATION_PREMIUM_SUBSCRIPTION", description: "A message sent when a user purchases an application premium subscription", deletable: true),
    .init(id: 33, name: "PRIVATE_CHANNEL_INTEGRATION_ADDED", description: "A message sent when a user adds an application to a group DM", deletable: false),
    .init(id: 34, name: "PRIVATE_CHANNEL_INTEGRATION_REMOVED", description: "A message sent when a user removes an application from a group DM", deletable: false),
    .init(id: 35, name: "PREMIUM_REFERRAL", description: "A message sent when a user gifts a premium (Nitro) referral", deletable: true),
    .init(id: 36, name: "GUILD_INCIDENT_ALERT_MODE_ENABLED", description: "A message sent when a user enabled lockdown for the guild", deletable: true),
    .init(id: 37, name: "GUILD_INCIDENT_ALERT_MODE_DISABLED", description: "A message sent when a user disables lockdown for the guild", deletable: true),
    .init(id: 38, name: "GUILD_INCIDENT_REPORT_RAID", description: "A message sent when a user reports a raid for the guild", deletable: true),
    .init(id: 39, name: "GUILD_INCIDENT_REPORT_FALSE_ALARM", description: "A message sent when a user reports a false alarm for the guild", deletable: true),
    .init(id: 40, name: "GUILD_DEADCHAT_REVIVE_PROMPT", description: "A message sent when no one sends a message in the current channel for 1 hour", deletable: true),
    .init(id: 41, name: "CUSTOM_GIFT", description: "A message sent when a user buys another user a gift", deletable: true),
    .init(id: 42, name: "GUILD_GAMING_STATS_PROMPT", description: "A message sent showing guild gaming stats", deletable: true),
    .init(id: 43, name: "POLL", description: "A message sent when a user posts a poll", deletable: true),
    .init(id: 44, name: "PURCHASE_NOTIFICATION", description: "A message sent when a user purchases a guild product", deletable: true),
    .init(id: 45, name: "VOICE_HANGOUT_INVITE", description: "A message sent when a user invites another user to hangout in a voice channel", deletable: true),
    .init(id: 46, name: "POLL_RESULT", description: "A message sent when a poll is finalized", deletable: true),
    .init(id: 47, name: "CHANGELOG", description: "A message sent by Discord Updates when a new changelog is posted", deletable: true),
    .init(id: 48, name: "NITRO_NOTIFICATION", description: "A message sent when a Nitro promotion is triggered", deletable: true),
    .init(id: 49, name: "CHANNEL_LINKED_TO_LOBBY", description: "A message sent when a voice channel is linked to a lobby", deletable: true),
    .init(id: 50, name: "GIFTING_PROMPT", description: "A local-only ephemeral message sent when prompted to gift Nitro", deletable: true),
    .init(id: 51, name: "IN_GAME_MESSAGE_NUX", description: "A message sent when a user receives an in-game message NUX", deletable: true),
    .init(id: 52, name: "GUILD_JOIN_REQUEST_ACCEPT_NOTIFICATION", description: "A message sent when a user accepts a guild join request", deletable: true),
    .init(id: 53, name: "GUILD_JOIN_REQUEST_REJECT_NOTIFICATION", description: "A message sent when a user rejects a guild join request", deletable: true),
    .init(id: 54, name: "GUILD_JOIN_REQUEST_WITHDRAWN_NOTIFICATION", description: "A message sent when a user withdraws a guild join request", deletable: true),
    .init(id: 55, name: "HD_STREAMING_UPGRADED", description: "A message sent when a user upgrades to HD streaming", deletable: true),
    .init(id: 56, name: "CHAT_WALLPAPER_SET", description: "A message sent when a user sets a DM wallpaper", deletable: false),
    .init(id: 57, name: "CHAT_WALLPAPER_REMOVE", description: "A message sent when a user removes a DM wallpaper", deletable: false),
    .init(id: 58, name: "REPORT_TO_MOD_DELETED_MESSAGE", description: "A message sent when a user resolves a moderation report by deleting a message", deletable: true),
    .init(id: 59, name: "REPORT_TO_MOD_TIMEOUT_USER", description: "A message sent when a user resolves a moderation report by timing out a user", deletable: true),
    .init(id: 60, name: "REPORT_TO_MOD_KICK_USER", description: "A message sent when a user resolves a moderation report by kicking a user", deletable: true),
    .init(id: 61, name: "REPORT_TO_MOD_BAN_USER", description: "A message sent when a user resolves a moderation report by banning a user", deletable: true),
    .init(id: 62, name: "REPORT_TO_MOD_CLOSED_REPORT", description: "A message sent when a user resolves a moderation report", deletable: true),
    .init(id: 63, name: "EMOJI_ADDED", description: "A message sent when a user adds a new emoji to a guild", deletable: true)
]

struct Message: Codable {
    let channelId: String
    var content: String
    let messageId: String
    var editedtimestamp: String?
    let timestamp: String?
    let type: Int?
    var typeName: String? {
        guard let type else { return nil }
        return messageTypes.first(where: { $0.id == type })?.name
    }
    var deletable: Bool? {
        guard let type else { return nil }
        return messageTypes.first(where: { $0.id == type })?.deletable
    }
    let guildId: String?
    let author: Author
    let messageReference: MessageReference?
    var attachments: [Attachment]?
    var embeds: [Embed]?
    var poll: Poll?
    let channelType: Int?
    let flags: Int?
    
    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case content
        case messageId = "id"
        case timestamp
        case type
        case guildId = "guild_id"
        case author
        case editedtimestamp = "edited_timestamp"
        case messageReference = "message_reference"
        case attachments
        case embeds
        case poll
        case channelType = "channel_type"
        case flags
    }
}

extension Attachment {
    var isLikelyVoiceMessage: Bool {
        let lowercasedName = filename?.lowercased() ?? ""
        let voiceNameMatch = lowercasedName.contains("voice-message")
        let extensionMatch = lowercasedName.hasSuffix(".ogg") || lowercasedName.hasSuffix(".m4a") || lowercasedName.hasSuffix(".mp4")
        let filenameMatch = (lowercasedName == "voice-message.ogg" || lowercasedName.hasSuffix("/voice-message.ogg")) || (voiceNameMatch && extensionMatch)
        let contentTypeLowercased = contentType?.lowercased()
        let contentTypeMatch = ["audio/ogg", "audio/opus", "audio/m4a", "audio/mp4"].contains { type in
            contentTypeLowercased?.contains(type) == true
        }
        let metadataMatch = (durationSeconds ?? 0) > 0 || waveform != nil
        return filenameMatch || contentTypeMatch || (metadataMatch && extensionMatch)
    }
}

struct Attachment: Codable {
    let url: String
    let id: String
    let filename: String?
    let contentType: String?
    let size: Int?
    let durationSeconds: Double?
    let waveform: String?
    
    enum CodingKeys: String, CodingKey {
        case url
        case id
        case filename
        case contentType = "content_type"
        case size
        case durationSeconds = "duration_secs"
        case waveform
    }
}

struct MessageReference: Codable {
    let messageId: String?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
}

extension MessageType {
    /// Message type IDs that have dedicated presentation in `MessageTypes`.
    static let customizableIDs: Set<Int> = [18, 46]
}

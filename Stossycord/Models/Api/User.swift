//
//  User.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct AvatarDecorationData: Codable, Equatable {
    let asset: String
    let sku_id: String
    let expires_at: String?
}

struct Collectibles: Codable, Equatable {
    let nameplate: Nameplate?
}

struct Nameplate: Codable, Equatable {
    let sku_id: String
    let asset: String
    let label: String
    let palette: String
}

struct Clan: Codable, Equatable {
    let identity_guild_id: String
    let identity_enabled: Bool
    let tag: String
    let badge: String
}

struct PrimaryGuild: Codable, Equatable {
    let identity_guild_id: String
    let identity_enabled: Bool
    let tag: String
    let badge: String
}

struct User: Codable, Equatable {
    let id: String
    let username: String
    let discriminator: String
    let avatar: String?
    let bot: Bool?
    let system: Bool?
    let mfa_enabled: Bool?
    let banner: String?
    let accentColor: Int?
    let globalName: String?
    let locale: String?
    let verified: Bool?
    let email: String?
    let flags: Int?
    let premiumType: Int?
    let publicFlags: Int?
    let banner_color: String?
    let phone: String?
    let nsfwAllowed: Bool?
    let purchased_flags: Int?
    let bio: String?
    let authenticatorTypes: [Int]?
    let linked_users: [String]?
    let avatar_decoration_data: AvatarDecorationData?
    let collectibles: Collectibles?
    let display_name_styles: [String]?
    let clan: Clan?
    let primary_guild: PrimaryGuild?
    let age_verification_status: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, username, discriminator, avatar, bot, system
        case mfa_enabled
        case banner
        case accentColor = "accent_color"
        case globalName = "global_name"
        case locale, verified, email, flags
        case premiumType = "premium_type"
        case publicFlags = "public_flags"
        case banner_color
        case phone
        case nsfwAllowed = "nsfw_allowed"
        case purchased_flags
        case bio
        case authenticatorTypes = "authenticator_types"
        case linked_users
        case avatar_decoration_data
        case collectibles
        case display_name_styles
        case clan
        case primary_guild
        case age_verification_status
    }
    
    init(
        id: String,
        username: String,
        discriminator: String,
        avatar: String?,
        bot: Bool? = nil,
        system: Bool? = nil,
        mfa_enabled: Bool? = nil,
        banner: String? = nil,
        accentColor: Int? = nil,
        globalName: String? = nil,
        locale: String? = nil,
        verified: Bool? = nil,
        email: String? = nil,
        flags: Int? = nil,
        premiumType: Int? = nil,
        publicFlags: Int? = nil,
        banner_color: String? = nil,
        phone: String? = nil,
        nsfwAllowed: Bool? = nil,
        purchased_flags: Int? = nil,
        bio: String? = nil,
        authenticatorTypes: [Int]? = nil,
        linked_users: [String]? = nil,
        avatar_decoration_data: AvatarDecorationData? = nil,
        collectibles: Collectibles? = nil,
        display_name_styles: [String]? = nil,
        clan: Clan? = nil,
        primary_guild: PrimaryGuild? = nil,
        age_verification_status: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.avatar = avatar
        self.bot = bot
        self.system = system
        self.mfa_enabled = mfa_enabled
        self.banner = banner
        self.accentColor = accentColor
        self.globalName = globalName
        self.locale = locale
        self.verified = verified
        self.email = email
        self.flags = flags
        self.premiumType = premiumType
        self.publicFlags = publicFlags
        self.banner_color = banner_color
        self.phone = phone
        self.nsfwAllowed = nsfwAllowed
        self.purchased_flags = purchased_flags
        self.bio = bio
        self.authenticatorTypes = authenticatorTypes
        self.linked_users = linked_users
        self.avatar_decoration_data = avatar_decoration_data
        self.collectibles = collectibles
        self.display_name_styles = display_name_styles
        self.clan = clan
        self.primary_guild = primary_guild
        self.age_verification_status = age_verification_status
    }
}

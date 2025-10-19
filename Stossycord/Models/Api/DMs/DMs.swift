//
//  DMs.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import Foundation

struct Recipient: Codable {
    let id: String
    let username: String
    let discriminator: String?
    let globalName: String?
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case discriminator
        case globalName = "global_name"
        case avatar
    }

    var asUser: User {
        User(
            id: id,
            username: username,
            discriminator: discriminator ?? "0000",
            avatar: avatar,
            globalName: globalName
        )
    }
}

struct DMs: Codable {
    let id: String
    let type: Int
    let last_message_id: String?
    let recipients: [User]?
    let name: String?
    
    var position: Int {
        return Int(last_message_id ?? "") ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case last_message_id
        case recipients
        case name
    }

    init(
        id: String,
        type: Int,
        last_message_id: String?,
        recipients: [User]?,
        name: String?
    ) {
        self.id = id
        self.type = type
        self.last_message_id = last_message_id
        self.recipients = recipients
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let type = try container.decode(Int.self, forKey: .type)
        let lastMessageId = try container.decodeIfPresent(String.self, forKey: .last_message_id)
        let name = try container.decodeIfPresent(String.self, forKey: .name)

        if let decodedRecipients = try? container.decodeIfPresent([User].self, forKey: .recipients) {
            self.init(id: id,
                      type: type,
                      last_message_id: lastMessageId,
                      recipients: decodedRecipients,
                      name: name)
            return
        }

        if let fallbackRecipients = try? container.decodeIfPresent([Recipient].self, forKey: .recipients) {
            let mapped = fallbackRecipients.map { $0.asUser }
            self.init(id: id,
                      type: type,
                      last_message_id: lastMessageId,
                      recipients: mapped,
                      name: name)
            return
        }

        self.init(id: id,
                  type: type,
                  last_message_id: lastMessageId,
                  recipients: nil,
                  name: name)
    }
}

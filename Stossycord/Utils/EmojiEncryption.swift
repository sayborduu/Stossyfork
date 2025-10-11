//
//  EmojiEncryption.swift
//  Stossycord
//
//  Created by Alex Badi on 12/10/25.
//

import Foundation
import CryptoKit

enum EmojiEncryptionError: LocalizedError {
    case invalidCiphertext
    case encodingFailure

    var errorDescription: String? {
        switch self {
        case .invalidCiphertext:
            return "Unable to decode the encrypted emoji name."
        case .encodingFailure:
            return "Unable to encode the emoji name for encryption."
        }
    }
}

struct EmojiEncryptionContext {
    let storeID: String
    let token: String

    init(storeID: String, token: String) {
        self.storeID = storeID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(credentials: VercelBlobService.Credentials) {
        self.init(storeID: credentials.storeID, token: credentials.token)
    }

    private var password: String {
        let reversedToken = String(token.reversed())
        guard let reversedData = reversedToken.data(using: .utf8) else { return "" }
        let base64Reversed = reversedData.base64EncodedString()
        return "\(storeID)_token_\(base64Reversed)"
    }

    private var key: SymmetricKey {
        let passwordData = Data(password.utf8)
        let hash = SHA256.hash(data: passwordData)
        return SymmetricKey(data: hash)
    }

    func encrypt(_ plaintext: String) throws -> String {
        guard let data = plaintext.data(using: .utf8) else {
            throw EmojiEncryptionError.encodingFailure
        }
        let nonce = try AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        guard let combined = sealedBox.combined else {
            throw EmojiEncryptionError.encodingFailure
        }
        return Self.base64URLEncode(combined)
    }

    func decrypt(_ encoded: String) throws -> String {
        let normalized = Self.base64URLDecode(encoded)
        guard let data = normalized else {
            throw EmojiEncryptionError.invalidCiphertext
        }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        return String(decoding: decrypted, as: UTF8.self)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        let urlSafe = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return urlSafe
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var normalized = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: normalized)
    }
}

extension EmojiEncryptionContext {
    static func fromDefaults(_ defaults: UserDefaults = .standard) -> EmojiEncryptionContext? {
        let rawStoreID = defaults.string(forKey: "customEmojiStoreID")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawToken = defaults.string(forKey: "customEmojiBlobToken")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawStoreID.isEmpty, !rawToken.isEmpty else { return nil }
        return EmojiEncryptionContext(storeID: rawStoreID, token: rawToken)
    }

    static func decryptIfPossible(_ encrypted: String, defaults: UserDefaults = .standard) -> String {
        guard let context = EmojiEncryptionContext.fromDefaults(defaults) else { return encrypted }
        do {
            return try context.decrypt(encrypted)
        } catch {
            return encrypted
        }
    }
}

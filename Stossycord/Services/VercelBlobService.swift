//
//  VercelBlobService.swift
//  Stossycord
//
//  Created by Alex Badi on 11/10/25.
//

import Foundation

final class VercelBlobService {

	struct Credentials: Equatable {
		let storeID: String
		let token: String

		init(storeID: String, token: String) {
			let trimmedStoreID = storeID.trimmingCharacters(in: .whitespacesAndNewlines)
			let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
			self.storeID = trimmedStoreID
			self.token = trimmedToken
		}

		var isEmpty: Bool { storeID.isEmpty || token.isEmpty }

		var fullStoreIdentifier: String {
			if storeID.lowercased().hasPrefix("store_") {
				return storeID
			}
			return "store_\(storeID)"
		}

		var prefixPath: String { "" }
	}

	struct Emoji: Identifiable, Hashable {
		let id: String
		let encryptedFilename: String
		let encryptedBaseName: String
		let decryptedBaseName: String
		let contentType: String?
		let size: Int?
		let uploadedAt: Date?
		let downloadURL: URL

		var filename: String { encryptedFilename }
		var storageFilename: String { encryptedFilename }
		var encryptedName: String { encryptedBaseName }
		var displayName: String { decryptedBaseName }
		var name: String { decryptedBaseName }

		var isAnimated: Bool {
			guard let contentType else { return false }
			return contentType == "image/gif" || contentType == "image/apng"
		}

		var baseName: String { decryptedBaseName }
	}

	enum ServiceError: LocalizedError {
		case invalidCredentials
		case invalidURL
		case decodingFailed
		case http(status: Int, message: String?)

		var errorDescription: String? {
			switch self {
			case .invalidCredentials:
				return "Missing or invalid Vercel Blob credentials."
			case .invalidURL:
				return "Unable to create a request for the Vercel Blob API."
			case .decodingFailed:
				return "The Vercel Blob API returned an unexpected response."
			case .http(let status, let message):
				if let message, !message.isEmpty {
					return "Request failed (\(status)): \(message)"
				}
				return "Request failed with status code \(status)."
			}
		}
	}

	private let credentials: Credentials
	private let session: URLSession
	private let decoder: JSONDecoder
	private let iso8601: ISO8601DateFormatter
	private let encryptionContext: EmojiEncryptionContext

	init(credentials: Credentials, session: URLSession = .shared) {
		self.credentials = credentials
		self.session = session
		self.encryptionContext = EmojiEncryptionContext(credentials: credentials)

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		self.decoder = decoder

		self.iso8601 = ISO8601DateFormatter()
	}

	// MARK: - Public API

	func listEmojis(limit: Int = 200) async throws -> [Emoji] {
        guard !credentials.isEmpty else { throw ServiceError.invalidCredentials }

        var components = URLComponents(string: "https://blob.vercel-storage.com")
        components?.queryItems = [
            URLQueryItem(name: "prefix", value: credentials.prefixPath),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let payload = try decoder.decode(BlobListResponse.self, from: data)

        let filtered = payload.blobs.filter { item in
            let lastComponent = (item.pathname as NSString).lastPathComponent
            guard let range = lastComponent.range(of: ".stossymoji.", options: .caseInsensitive) else {
                return false
            }
            let ext = String(lastComponent[range.upperBound...])
            guard !ext.isEmpty else { return false }
            let invalidExtChars = CharacterSet.alphanumerics.inverted
            return ext.rangeOfCharacter(from: invalidExtChars) == nil
        }

		return filtered.map { $0.toEmoji(using: credentials.prefixPath,
										 fallbackFormatter: iso8601,
										 context: encryptionContext) }
    }

    func uploadEmoji(data: Data, filename: String, contentType: String?) async throws -> Emoji {
        guard !credentials.isEmpty else { throw ServiceError.invalidCredentials }
		let sanitized = try sanitizedFilename(from: filename, contentType: contentType)
        let pathname = credentials.prefixPath + sanitized
        print("uploading emoji: \(pathname)")

        var components = URLComponents(string: "https://blob.vercel-storage.com/\(pathname)")
        components?.queryItems = [
            URLQueryItem(name: "access", value: "public"),
        ]

        guard let url = components?.url else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        applyAuthHeaders(to: &request)
        request.setValue(contentType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("7", forHTTPHeaderField: "x-api-version")
        request.setValue("0", forHTTPHeaderField: "x-add-random-suffix")

        let (responseData, response) = try await session.upload(for: request, from: data)
        try validate(response: response, data: responseData)

		let item = try decoder.decode(BlobItem.self, from: responseData)
		return item.toEmoji(using: credentials.prefixPath,
							fallbackFormatter: iso8601,
							context: encryptionContext)
    }

    func renameEmoji(data: Data, oldPathname: String, newBaseName: String, contentType: String?) async throws -> Emoji {
        print("renaming emoji: \(oldPathname) -> \(newBaseName)")
        try await deleteEmoji(pathname: oldPathname)
		return try await uploadEmoji(data: data, filename: newBaseName, contentType: contentType)
    }

    func deleteEmoji(pathname: String) async throws {
        print("deleting emoji: \(pathname)")
        guard !credentials.isEmpty else { throw ServiceError.invalidCredentials }
        guard let url = URL(string: "https://blob.vercel-storage.com/delete") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["urls": [pathname]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

	// MARK: - Internal helpers

	private func applyAuthHeaders(to request: inout URLRequest) {
		request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
	}

	private func validate(response: URLResponse, data: Data?) throws {
		guard let httpResponse = response as? HTTPURLResponse else {
			throw ServiceError.http(status: -1, message: "No HTTP response.")
		}
		guard 200..<300 ~= httpResponse.statusCode else {
			let message: String?
			if let data, let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty {
				message = decoded
			} else {
				message = nil
			}
			throw ServiceError.http(status: httpResponse.statusCode, message: message)
		}
	}



	private func sanitizedFilename(from raw: String, contentType: String? = nil) throws -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

		let baseRaw = (trimmed as NSString).deletingPathExtension
		let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
		let components = baseRaw
			.components(separatedBy: allowed.inverted)
			.filter { !$0.isEmpty }
		var cleaned = components.joined(separator: "-")
		if cleaned.isEmpty {
			cleaned = "emoji-\(UUID().uuidString)"
		}

		func ext(forContentType ct: String) -> String? {
			switch ct.lowercased() {
			case "image/png": return "png"
			case "image/apng": return "png"
			case "image/gif": return "gif"
			case "image/webp": return "webp"
			case "image/jpeg", "image/jpg": return "jpg"
			case "image/svg+xml": return "svg"
			case "image/x-icon", "image/vnd.microsoft.icon": return "ico"
			case "image/avif": return "avif"
			default: return nil
			}
		}

		let origExt = (trimmed as NSString).pathExtension.lowercased()
		let chosenExt = contentType.flatMap { ext(forContentType: $0) } ?? (origExt.isEmpty ? "png" : origExt)
		let encryptedBase = try encryptionContext.encrypt(cleaned)
		return "\(encryptedBase).stossymoji.\(chosenExt)"
	}

	// MARK: - Response models

	private struct BlobListResponse: Decodable {
		let blobs: [BlobItem]

		private enum CodingKeys: String, CodingKey {
			case blobs
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			blobs = try container.decode([BlobItem].self, forKey: .blobs)
		}
	}



	private struct BlobItem: Decodable {
		let pathname: String
		let size: Int?
		let contentType: String?
		let uploadedAt: Date?
		let url: URL?
		let downloadUrl: URL?

		private enum CodingKeys: String, CodingKey {
			case pathname
			case size
			case contentType
			case uploadedAt
			case url
			case downloadUrl
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			pathname = try container.decode(String.self, forKey: .pathname)
			size = try container.decodeIfPresent(Int.self, forKey: .size)
			contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
			uploadedAt = try container.decodeIfPresent(Date.self, forKey: .uploadedAt)
			url = try container.decodeIfPresent(URL.self, forKey: .url)
			downloadUrl = try container.decodeIfPresent(URL.self, forKey: .downloadUrl)
		}

		func toEmoji(using prefix: String,
				   fallbackFormatter: ISO8601DateFormatter,
				   context: EmojiEncryptionContext) -> Emoji {
			let filename: String
			if pathname.hasPrefix(prefix) {
				filename = String(pathname.dropFirst(prefix.count))
			} else if let range = pathname.range(of: "/") {
				filename = String(pathname[range.upperBound...])
			} else {
				filename = pathname
			}

			let encryptedBase: String
			let decryptedBase: String
			if let dotRange = filename.range(of: ".stossymoji.", options: .caseInsensitive) {
				let base = String(filename[..<dotRange.lowerBound])
				encryptedBase = base
				do {
					decryptedBase = try context.decrypt(base)
				} catch {
					decryptedBase = base
				}
			} else {
				encryptedBase = filename
				decryptedBase = filename
			}

			let resolvedURL = url ?? downloadUrl ?? URL(string: "https://blob.vercel-storage.com/\(pathname)")!
			return Emoji(id: pathname,
						 encryptedFilename: filename,
						 encryptedBaseName: encryptedBase,
						 decryptedBaseName: decryptedBase,
						 contentType: contentType,
						 size: size,
						 uploadedAt: uploadedAt,
						 downloadURL: resolvedURL)
		}
	}
}


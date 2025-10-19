//
//  SendVoiceMessage.swift
//  Stossycord
//
//  Created by Alex Badi on 15/10/2025.
//

import Foundation

struct VoiceMessageSender {
    private struct UploadRequest: Encodable {
        struct File: Encodable {
            let filename: String
            let file_size: Int
            let id: String
        }

        let files: [File]
    }

    private struct UploadResponse: Decodable {
        struct Attachment: Decodable {
            let id: Int
            let upload_url: String
            let upload_filename: String
        }

        let attachments: [Attachment]
    }

    private struct SendMessagePayload: Encodable {
        struct Attachment: Encodable {
            let id: String
            let filename: String
            let uploaded_filename: String
            let duration_secs: Double
            let waveform: String
        }

        let flags: Int
        let attachments: [Attachment]
    }

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func sendVoiceMessage(clip: VoiceRecordingManager.Clip, token: String, channelId: String) async throws {
        let uploadInfo = try await requestUploadURL(clip: clip, token: token, channelId: channelId)
        guard let attachment = uploadInfo.attachments.first,
              let uploadURL = URL(string: attachment.upload_url) else {
            throw VoiceMessageError.invalidUploadResponse
        }

        try await uploadFile(clip: clip, uploadURL: uploadURL, token: token)
        try await postMessage(clip: clip, attachment: attachment, token: token, channelId: channelId)
    }

    // MARK: - Upload URL
    private func requestUploadURL(clip: VoiceRecordingManager.Clip, token: String, channelId: String) async throws -> UploadResponse {
        let url = URL(string: "https://discord.com/api/v10/channels/\(channelId)/attachments")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")

        let size = max(1, clip.fileSize)
        let body = UploadRequest(files: [
            .init(filename: clip.filename, file_size: size, id: "0")
        ])

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        try VoiceMessageError.validateResponse(response, data: data)

        return try JSONDecoder().decode(UploadResponse.self, from: data)
    }

    // MARK: - Upload File
    private func uploadFile(clip: VoiceRecordingManager.Clip, uploadURL: URL, token: String) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
    request.addValue(clip.mimeType, forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")

        let fileData = try Data(contentsOf: clip.fileURL)
        request.httpBody = fileData

        let (_, response) = try await urlSession.data(for: request)
        try VoiceMessageError.validateResponse(response)
    }

    // MARK: - Final message
    private func postMessage(clip: VoiceRecordingManager.Clip, attachment: UploadResponse.Attachment, token: String, channelId: String) async throws {
        let url = URL(string: "https://discord.com/api/v10/channels/\(channelId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")
        addCommonHeaders(to: &request)

        let payload = SendMessagePayload(
            flags: 8192,
            attachments: [
                .init(
                    id: "0",
                    filename: clip.filename,
                    uploaded_filename: attachment.upload_filename,
                    duration_secs: clip.roundedDuration,
                    waveform: clip.base64Waveform
                )
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        try VoiceMessageError.validateResponse(response, data: data)
    }

    private func addCommonHeaders(to request: inout URLRequest) {
        request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
        request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")

        let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
        let currentTimeZone = CurrentDeviceInfo.shared.currentTimeZone
        let Country: String = CurrentDeviceInfo.shared.Country
        let timeZoneIdentifier = currentTimeZone.identifier

        request.addValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
        request.addValue("\(currentTimeZone)-\(Country)", forHTTPHeaderField: "X-Discord-Locale")
        request.addValue(timeZoneIdentifier, forHTTPHeaderField: "X-Discord-Timezone")
        request.addValue(deviceInfo.toBase64() ?? "base64", forHTTPHeaderField: "X-Super-Properties")
    }
}

enum VoiceMessageError: Error {
    case invalidUploadResponse
    case invalidResponse(status: Int, body: String?)
}

private extension VoiceMessageError {
    static func validateResponse(_ response: URLResponse?, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard 200..<300 ~= httpResponse.statusCode else {
            let bodyString = data.flatMap { String(data: $0, encoding: .utf8) }
            throw VoiceMessageError.invalidResponse(status: httpResponse.statusCode, body: bodyString)
        }
    }
}

//
//  CustomEmojiManager.swift
//  Stossycord
//
//  Created by Alex Badi on 11/10/25.
//

import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics

@MainActor
final class CustomEmojiManager: ObservableObject {

    private enum EmojiProcessingError: LocalizedError {
        case unsupportedFormat
        case imageCreationFailed
        case contextCreationFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "Selected file isn't a supported image type."
            case .imageCreationFailed:
                return "Couldn't read the selected image."
            case .contextCreationFailed:
                return "Couldn't prepare image for resizing."
            case .encodingFailed:
                return "Couldn't encode resized image."
            }
        }
    }

    private let emojiTargetSize = CGSize(width: 48, height: 48)

    enum State {
        case disabled
        case missingCredentials
        case ready
    }

    @Published private(set) var state: State = .disabled
    @Published private(set) var emojis: [VercelBlobService.Emoji] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isMutating: Bool = false
    @Published var errorMessage: String?

    private var service: VercelBlobService?
    private var credentials: VercelBlobService.Credentials?
    private var currentReloadTask: Task<Void, Never>?

    deinit {
        currentReloadTask?.cancel()
    }

    func configure(enabled: Bool, storeID: String, token: String) {
        currentReloadTask?.cancel()
        errorMessage = nil

        guard enabled else {
            state = .disabled
            service = nil
            credentials = nil
            emojis = []
            return
        }

        let sanitizedStoreID = storeID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedStoreID.isEmpty, !sanitizedToken.isEmpty else {
            state = .missingCredentials
            service = nil
            credentials = nil
            emojis = []
            return
        }

        let newCredentials = VercelBlobService.Credentials(storeID: sanitizedStoreID, token: sanitizedToken)
        if newCredentials != credentials {
            credentials = newCredentials
            service = VercelBlobService(credentials: newCredentials)
        }

        state = .ready
        reload()
    }

    func reload() {
        guard state == .ready, let service else { return }

        currentReloadTask?.cancel()
        isLoading = true
        errorMessage = nil

        currentReloadTask = Task { [weak self] in
            do {
                let emojis = try await service.listEmojis()
                await MainActor.run {
                    self?.emojis = emojis.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }

    func uploadEmoji(from fileURL: URL) {
        guard state == .ready, let service else { return }

        isMutating = true
        errorMessage = nil

        Task(priority: .userInitiated) { [weak self] in
            do {
                guard let self else { return }
                let originalData = try await self.readData(from: fileURL)
                let originalFilename = fileURL.lastPathComponent
                let originalMimeType = self.mimeTypeForFile(at: fileURL)

                let prepared = try self.prepareEmojiUploadData(data: originalData,
                                                               originalFilename: originalFilename,
                                                               mimeType: originalMimeType)

                let emoji = try await service.uploadEmoji(data: prepared.data,
                                                          filename: prepared.filename,
                                                          contentType: prepared.contentType)
                await MainActor.run {
                    self.emojis.append(emoji)
                    self.emojis.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    self.isMutating = false
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.isMutating = false
                }
            }
        }
    }

    func deleteEmoji(_ emoji: VercelBlobService.Emoji) {
        guard state == .ready, let service else { return }

        isMutating = true
        errorMessage = nil

        Task(priority: .userInitiated) { [weak self] in
            do {
                try await service.deleteEmoji(pathname: emoji.id)
                await MainActor.run {
                    guard let self else { return }
                    self.emojis.removeAll { $0.id == emoji.id }
                    self.isMutating = false
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.isMutating = false
                }
            }
        }
    }

    func renameEmoji(_ emoji: VercelBlobService.Emoji, to newBaseName: String) {
        guard state == .ready, let service else { return }

        isMutating = true
        errorMessage = nil

        Task(priority: .userInitiated) { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: emoji.downloadURL)
                if let originalSize = emoji.size, data.count != originalSize {
                    throw NSError(domain: "CustomEmojiManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloaded data size (\(data.count)) doesn't match original size (\(originalSize))"])
                }
                let newEmoji = try await service.renameEmoji(data: data, oldPathname: emoji.id, newBaseName: newBaseName, contentType: emoji.contentType)
                await MainActor.run {
                    guard let self else { return }
                    if let index = self.emojis.firstIndex(where: { $0.id == emoji.id }) {
                        self.emojis[index] = newEmoji
                        self.emojis.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    }
                    self.isMutating = false
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.isMutating = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func prepareEmojiUploadData(data: Data, originalFilename: String, mimeType: String?) throws -> (data: Data, filename: String, contentType: String?) {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw EmojiProcessingError.imageCreationFailed
        }

        let isImage: Bool
        if let mimeType, let type = UTType(mimeType: mimeType) {
            isImage = type.conforms(to: .image)
        } else if let cfType = CGImageSourceGetType(imageSource),
                  let type = UTType(cfType as String) {
            isImage = type.conforms(to: .image)
        } else {
            isImage = false
        }

        guard isImage else {
            throw EmojiProcessingError.unsupportedFormat
        }

        guard let orientedThumbnail = createOrientedThumbnail(from: imageSource) else {
            throw EmojiProcessingError.imageCreationFailed
        }

        let resizedImage = try resizeImage(orientedThumbnail, to: emojiTargetSize)
        let encodedData = try encodePNG(from: resizedImage)

        let sanitizedFilename = ((originalFilename as NSString).deletingPathExtension).appending(".png")
    return (encodedData, sanitizedFilename, "image/png")
    }

    private func createOrientedThumbnail(from source: CGImageSource) -> CGImage? {
        let maxDimension = Int(max(emojiTargetSize.width, emojiTargetSize.height))
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func resizeImage(_ image: CGImage, to targetSize: CGSize) throws -> CGImage {
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
            throw EmojiProcessingError.contextCreationFailed
        }

        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bitsPerComponent = 8
        let bytesPerRow = width * 4

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw EmojiProcessingError.contextCreationFailed
        }

        context.interpolationQuality = .high
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        context.fill(CGRect(origin: .zero, size: targetSize))

        let scale = min(targetSize.width / CGFloat(image.width), targetSize.height / CGFloat(image.height))
        let scaledSize = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let origin = CGPoint(x: (targetSize.width - scaledSize.width) / 2.0, y: (targetSize.height - scaledSize.height) / 2.0)

        context.draw(image, in: CGRect(origin: origin, size: scaledSize))

        guard let outputImage = context.makeImage() else {
            throw EmojiProcessingError.imageCreationFailed
        }

        return outputImage
    }

    private func encodePNG(from image: CGImage) throws -> Data {
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, UTType.png.identifier as CFString, 1, nil) else {
            throw EmojiProcessingError.encodingFailed
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw EmojiProcessingError.encodingFailed
        }

        return destinationData as Data
    }

    private func readData(from url: URL) async throws -> Data {
        #if os(macOS)
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        #else
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        #endif
        return try Data(contentsOf: url)
    }

    private func mimeTypeForFile(at url: URL) -> String? {
        let ext = url.pathExtension
        guard !ext.isEmpty,
              let utType = UTType(filenameExtension: ext.lowercased()) else {
            return nil
        }
        return utType.preferredMIMEType
    }
}

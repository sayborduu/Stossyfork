//
//  CustomEmojis.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/2025.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct CustomEmojiViewSettings: View {
    @AppStorage("customEmojiStorageEnabled") private var customEmojiStorageEnabled: Bool = false
    @AppStorage("customEmojiHyperlinkText") private var customEmojiHyperlinkText: String = "ﹺ"
    @AppStorage("useCustomEmojiBackend") private var useCustomEmojiBackend: Bool = false
    @AppStorage("customEmojiStoreID") private var customEmojiStoreID: String = ""
    @AppStorage("customEmojiBlobToken") private var customEmojiBlobToken: String = ""
    @AppStorage("customEmojiBackendURL") private var customEmojiBackendURL: String = "https://stossymoji.vercel.app"

    @StateObject private var customEmojiManager = CustomEmojiManager()
    @State private var showingEmojiImporter: Bool = false
    @State private var emojiPendingDeletion: VercelBlobService.Emoji?
    @State private var editingEmoji: VercelBlobService.Emoji?
    @State private var editingName: String = ""

    @State private var destination: SettingsDestination

    init(destination: SettingsDestination) {
        _destination = State(initialValue: destination)
    }

    var body: some View {
        List {
                Section(header: Text("Blob configuration").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)) {
                    customEmojiSettings()
                }

                Section(header: Text("Your emojis")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)) {
                    customEmojiManagement()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(destination.titleKey)
            .fileImporter(
                isPresented: $showingEmojiImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        customEmojiManager.uploadEmoji(from: url)
                    } else {
                        customEmojiManager.errorMessage = "No file selected"
                    }
                case .failure(let error):
                    customEmojiManager.errorMessage = error.localizedDescription
                }
            }
            .confirmationDialog(
                "Delete emoji?",
                isPresented: Binding(
                    get: { emojiPendingDeletion != nil },
                    set: { newValue in
                        if !newValue {
                            emojiPendingDeletion = nil
                        }
                    }
                ),
                presenting: emojiPendingDeletion
            ) { emoji in
                Button("Delete \"\(emoji.name)\"", role: .destructive) {
                    customEmojiManager.deleteEmoji(emoji)
                    emojiPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    emojiPendingDeletion = nil
                }
            } message: { _ in
                Text("This will permanently remove the emoji from your Vercel Blob store.")
            }
            .onAppear(perform: refreshCustomEmojiManagerConfiguration)
            .onChange(of: customEmojiStorageEnabled) { _ in
                refreshCustomEmojiManagerConfiguration()
            }
            .onChange(of: customEmojiStoreID) { _ in
                refreshCustomEmojiManagerConfiguration()
            }
            .onChange(of: customEmojiBlobToken) { _ in
                refreshCustomEmojiManagerConfiguration()
            }
    }

    @ViewBuilder
    private func customEmojiSettings() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $customEmojiStorageEnabled) {
                Label("Enable Vercel Blob Store", systemImage: customEmojiStorageEnabled ? "checkmark.circle.fill" : "checkmark.circle")
            }

            Text("Store your custom emoji set in a Vercel Blob database. Stossycord only talks to Vercel on your behalf.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    if let url = URL(string: "https://vercel.com/") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    Label("Open Vercel Dashboard", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if customEmojiStorageEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Blob credentials")
                        .font(.headline)

                    TextField("Unique Store ID", text: $customEmojiStoreID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: customEmojiStoreID) { newValue in
                            if newValue.contains("store_") {
                                customEmojiStoreID = newValue.replacingOccurrences(of: "store_", with: "")
                            }
                        }

                    Text("Must be saved without the 'store_' prefix. Stossycord will remove it automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        
                    Divider()

                    SecureField("BLOB_READ_WRITE_TOKEN", text: $customEmojiBlobToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)

                    Divider()

                    Toggle(isOn: $useCustomEmojiBackend) {
                        Label("Use custom emoji backend", systemImage: useCustomEmojiBackend ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    Text("While this is enabled, Stossycord will send a shortened URL to Discord instead of the full Blob URL.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                    TextField("Custom emoji backend", text: $customEmojiBackendURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Text("This endpoint is used to send emojis on Discord. Your credentials never go there. It simply shortens the default Blob URL for Discord messages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("Hyperlink text")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    
                    TextField("Emoji hyperlink text", text: $customEmojiHyperlinkText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Divider()

                    VStack(alignment: .center, spacing: 5) {
                        if #available(iOS 26.0, *) {
                            Button("Reset backend") {
                                customEmojiBackendURL = "https://stossymoji.vercel.app"
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 16)
                            .glassEffect(.regular.tint(.secondary).interactive())
                            .foregroundColor(.white)
                            .buttonStyle(.plain)

                            if let repoURL = URL(string: "https://github.com/sayborduu/stossymoji") {
                                Link(destination: repoURL) {
                                    Text("Host your own")
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)
                                        .padding(.horizontal, 16)
                                        .glassEffect(.regular.tint(.secondary).interactive())
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }

                            Button("Reset hyperlink text") {
                                customEmojiHyperlinkText = "ﹺ"
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 16)
                            .glassEffect(.regular.tint(.secondary).interactive())
                            .foregroundColor(.white)
                            .buttonStyle(.plain)
                        } else {
                            Button("Reset backend") {
                                customEmojiBackendURL = "https://stossymoji.vercel.app"
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.secondary.opacity(0.1))
                            )
                            .buttonStyle(.plain)

                            if let repoURL = URL(string: "https://github.com/sayborduu/stossymoji") {
                                Link(destination: repoURL) {
                                    Text("Host your own")
                                        .padding(.top, 4)
                                        .padding(.bottom, 4)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(.secondary.opacity(0.1))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            Button("Reset backend") {
                                customEmojiHyperlinkText = "ﹺ"
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.secondary.opacity(0.1))
                            )
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func customEmojiManagement() -> some View {
        switch customEmojiManager.state {
        case .disabled:
            Text("Enable the Vercel Blob Store above to manage your custom emojis.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .missingCredentials:
            VStack(alignment: .leading, spacing: 8) {
                Text("Add your Store ID and BLOB_READ_WRITE_TOKEN to continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Both fields are required before Stossycord can talk to the Vercel Blob API.")
                    .font(.footnote)
                    .foregroundStyle(.secondary.opacity(0.8))
            }

        case .ready:
            customEmojiManagerReadyView()
        }
    }

    @ViewBuilder
    private func customEmojiManagerReadyView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = customEmojiManager.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if customEmojiManager.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading emojis…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if customEmojiManager.emojis.isEmpty {
                if !customEmojiManager.isLoading {
                    Text("You haven't uploaded any custom emojis yet. Upload an image to get started.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(customEmojiManager.emojis) { emoji in
                    emojiRow(for: emoji)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    showingEmojiImporter = true
                } label: {
                    Label("Upload emoji", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(customEmojiManager.isMutating)

                Button {
                    customEmojiManager.reload()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(customEmojiManager.isLoading || customEmojiManager.isMutating)

                Spacer()

                if customEmojiManager.isMutating {
                    ProgressView()
                }
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func emojiRow(for emoji: VercelBlobService.Emoji) -> some View {
        HStack(spacing: 12) {
            emojiPreview(for: emoji)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                if editingEmoji?.id == emoji.id {
                    TextField("Name", text: $editingName, onCommit: {
                        if !editingName.isEmpty && editingName != emoji.baseName {
                            customEmojiManager.renameEmoji(emoji, to: editingName)
                        }
                        editingEmoji = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .lineLimit(1)
                } else {
                    Text(emoji.baseName)
                        .font(.subheadline)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let sizeText = formattedSize(emoji.size) {
                            Text(sizeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let uploadedText = formattedUploadDate(emoji.uploadedAt) {
                            Text(uploadedText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if editingEmoji?.id == emoji.id {
                Button("Cancel") {
                    editingEmoji = nil
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    editingEmoji = emoji
                    editingName = emoji.baseName
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .disabled(customEmojiManager.isMutating)

                Button(role: .destructive) {
                    emojiPendingDeletion = emoji
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(customEmojiManager.isMutating)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func emojiPreview(for emoji: VercelBlobService.Emoji) -> some View {
        UncachedAsyncImage(url: emoji.downloadURL)
    }

    private func formattedSize(_ bytes: Int?) -> String? {
        guard let bytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func formattedUploadDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    func refreshCustomEmojiManagerConfiguration() {
        customEmojiManager.configure(
            enabled: customEmojiStorageEnabled,
            storeID: customEmojiStoreID,
            token: customEmojiBlobToken
        )
    }

    private struct UncachedAsyncImage: View {
        let url: URL
        
        @State private var image: Image? = nil
        @State private var isLoading = true
        @State private var error: Error? = nil
        
        var body: some View {
            Group {
                if let image = image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if isLoading {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(.circular)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            Image(systemName: "questionmark")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .task {
                await loadImage()
            }
        }
        
        private func loadImage() async {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, _) = try await URLSession.shared.data(for: request)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = Image(uiImage: uiImage)
                        self.isLoading = false
                    }
                } else {
                    throw NSError(domain: "UncachedAsyncImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
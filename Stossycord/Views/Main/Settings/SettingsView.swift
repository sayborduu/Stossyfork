//
//  SettingsView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI
import KeychainSwift
import LocalAuthentication
import MusicKit
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SettingsView: View {
    @State var isspoiler: Bool = true
    let keychain = KeychainSwift()
    @State var showAlert: Bool = false
    @State var showPopover = false
    @State var guildID = ""
    @EnvironmentObject private var presenceManager: PresenceManager
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    @AppStorage("disableProfilePicturesCache") private var disableProfilePicturesCache: Bool = false
    @AppStorage("disableProfileCache") private var disableProfileCache: Bool = false
    @AppStorage("hideRestrictedChannels") private var hideRestrictedChannels: Bool = false
    @AppStorage("useNativePicker") private var useNativePicker: Bool = true
    @AppStorage("useRedesignedMessages") private var useRedesignedMessages: Bool = true
    @AppStorage("useDiscordFolders") private var useDiscordFolders: Bool = true
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = MessageBubbleStyle.imessage.rawValue
    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true
    @AppStorage(DesignSettingsKeys.customMessageBubbleJSON) private var customBubbleJSON: String = ""
    @AppStorage("privacyMode") private var privacyModeRawValue: String = PrivacyMode.defaultMode.rawValue
    @AppStorage("privacyCustomLoadEmojis") private var privacyCustomLoadEmojis: Bool = true
    @AppStorage("discordEmojiReplacement") private var discordEmojiReplacement: String = ""
    @AppStorage("allowDestructiveActions") private var allowDestructiveActions: Bool = false
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
    
    private enum SettingsDestination: String, CaseIterable, Hashable {
        case appearance
        case design
        case cache
        case privacy
        case customEmojis
        case beta
        case presence
        case token
        case warningZone

        var titleKey: LocalizedStringKey {
            switch self {
            case .appearance: return "settings.section.appearanceAndDesign"
            case .design: return "settings.section.design"
            case .cache: return "settings.section.cache"
            case .privacy: return "settings.section.privacy"
            case .customEmojis: return "Custom Emojis"
            case .beta: return "settings.section.beta"
            case .presence: return "settings.section.presence"
            case .token: return "settings.section.token"
            case .warningZone: return "settings.section.warningZone"
            }
        }

        var subtitleKey: LocalizedStringKey? { nil }

        var detailDescriptionKey: LocalizedStringKey? { nil }

        var iconName: String {
            switch self {
            case .appearance: return "paintbrush"
            case .design: return "text.bubble"
            case .cache: return "internaldrive"
            case .privacy: return "lock.shield"
            case .customEmojis: return "face.smiling"
            case .beta: return "testtube.2"
            case .presence: return "music.note.list"
            case .token: return "key.fill"
            case .warningZone: return "exclamationmark.triangle"
            }
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(for destination: SettingsDestination, @ViewBuilder content: () -> Content) -> some View {
        SettingsSection(
            title: destination.titleKey,
            description: destination.detailDescriptionKey,
            content: content
        )
    }

    private var currentPrivacyMode: PrivacyMode {
        PrivacyMode(rawValue: privacyModeRawValue) ?? PrivacyMode.defaultMode
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    settingsHeader
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink(value: SettingsDestination.appearance) {
                    sectionRow(for: .appearance)
                }

                ForEach(SettingsDestination.allCases.filter { $0 != .appearance && $0 != .design }, id: \.self) { destination in
                    NavigationLink(value: destination) {
                        sectionRow(for: destination)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("settings.title")
            .navigationDestination(for: SettingsDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .alert(isPresented: $showAlert) {
            .init(
                title: Text("settings.alert.tokenResetTitle"),
                message: Text("settings.alert.tokenResetMessage"))
        }
        .fileImporter(isPresented: $showingEmojiImporter,
                       allowedContentTypes: [.image],
                       allowsMultipleSelection: false) { result in
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
            isPresented: .init(
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
        .onAppear {
            ensureValidMessageStyle()
            ensureValidPrivacyMode()
            presenceManager.refreshAuthorizationStatus()
            refreshCustomEmojiManagerConfiguration()
        }
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
    private func destinationView(for destination: SettingsDestination) -> some View {
        switch destination {
        case .appearance:
            List {
                Section(header: Text("settings.section.appearance")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)) {

                    Toggle("settings.toggle.disableAnimatedAvatars", isOn: $disableAnimatedAvatars)
                        .help(Text("settings.toggle.disableAnimatedAvatars.help"))

                    Toggle("settings.toggle.disableProfilePictureTap", isOn: $disableProfilePictureTap)
                        .help(Text("settings.toggle.disableProfilePictureTap.help"))
                }

                Section(header: Text("settings.section.design")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)) {

                    Picker("settings.picker.messageStyle", selection: $messageStyleRawValue) {
                        ForEach(MessageBubbleStyle.selectableCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.segmented)
                    #endif

                    Toggle("settings.toggle.showSelfAvatar", isOn: $showSelfAvatar)
                        .help(Text("settings.toggle.showSelfAvatar.help"))

                    let selectedStyle = MessageBubbleStyle(rawValue: messageStyleRawValue) ?? .imessage
                    if selectedStyle == .custom {
                        Section {
                            TextEditor(text: $customBubbleJSON)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 160)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            #endif

                            if !MessageBubbleVisualConfiguration.isCustomJSONValid(customBubbleJSON) {
                                Text("settings.customBubble.invalid")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            HStack(spacing: 12) {
                                Button("settings.customBubble.loadSample") {
                                    customBubbleJSON = MessageBubbleVisualConfiguration.sampleJSON
                                }

                                Button("common.clear") {
                                    customBubbleJSON = ""
                                }
                                .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(destination.titleKey)

        case .design:
            settingsSection(for: destination) {
                designSettings()
            }

        case .cache:
            settingsSection(for: destination) {
                cacheSettings()
            }

        case .privacy:
            List {
                Section(header: Text("Privacy Modes")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)) {
                    privacySettings()
                }

                if (currentPrivacyMode == .custom && !privacyCustomLoadEmojis) || currentPrivacyMode == .privacy {
                    Section(header: Text("Emoji Replacement")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)) {
                        VStack {
                            if !privacyCustomLoadEmojis || currentPrivacyMode == .privacy {
                                TextField("▢ replacement", text: $discordEmojiReplacement)
                                    .limit(value: $discordEmojiReplacement, length: 4)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text("When emojis are disabled, you can customize how they are represented in messages. Use `%n` as a placeholder for the emoji name.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(destination.titleKey)

        case .customEmojis:
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

        case .beta:
            settingsSection(for: destination) {
                betaSettings()
            }

        case .presence:
            settingsSection(for: destination) {
                presenceSettings()
            }

        case .token:
            settingsSection(for: destination) {
                tokenSettings()
            }

        case .warningZone:
            settingsSection(for: destination) {
                destructiveSettings()
            }
            .sheet(isPresented: $showPopover) {
                destructiveConfirmation
            }
        }
    }

    @ViewBuilder
    private func sectionRow(for destination: SettingsDestination) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: destination.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.titleKey)
                    .font(.headline)

                if let subtitle = destination.subtitleKey {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Settings Header
    private var settingsHeader: some View {
        VStack(spacing: 8) {
            appIconImage
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(appDisplayName)
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(appVersion)
                .font(.caption)
                .foregroundStyle(.secondary)

            if #available(iOS 26.0, *) {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/Stossycord/Stossycord") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)
                .glassEffect(.regular.tint(.blue).interactive())
                .foregroundColor(.white)
            } else {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/Stossycord/Stossycord") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(groupedBackgroundColor)
        )
    }

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
            "Stossycord"
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if build.isEmpty || build == version {
            return version
        }
        return "\(version) (\(build))"
    }

    private var appIconImage: Image { AppResources.appIconImage }

    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemGroupedBackground)
        #endif
    }

    // MARK: - Settings Sections

    @ViewBuilder
    private func appearanceSettings() -> some View {
        Toggle("settings.toggle.disableAnimatedAvatars", isOn: $disableAnimatedAvatars)
            .help(Text("settings.toggle.disableAnimatedAvatars.help"))

        Toggle("settings.toggle.disableProfilePictureTap", isOn: $disableProfilePictureTap)
            .help(Text("settings.toggle.disableProfilePictureTap.help"))
    }

    @ViewBuilder
    private func designSettings() -> some View {
        Picker("settings.picker.messageStyle", selection: $messageStyleRawValue) {
            ForEach(MessageBubbleStyle.selectableCases) { style in
                Text(style.displayName).tag(style.rawValue)
            }
        }
        #if os(iOS)
        .pickerStyle(.segmented)
        #endif

        Toggle("settings.toggle.showSelfAvatar", isOn: $showSelfAvatar)
            .help(Text("settings.toggle.showSelfAvatar.help"))

        let selectedStyle = MessageBubbleStyle(rawValue: messageStyleRawValue) ?? .imessage
        if selectedStyle == .custom {
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.customBubble.label")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextEditor(text: $customBubbleJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                #endif

                if !MessageBubbleVisualConfiguration.isCustomJSONValid(customBubbleJSON) {
                    Text("settings.customBubble.invalid")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button("settings.customBubble.loadSample") {
                        customBubbleJSON = MessageBubbleVisualConfiguration.sampleJSON
                    }

                    Button("common.clear") {
                        customBubbleJSON = ""
                    }
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func cacheSettings() -> some View {
        Toggle("settings.toggle.disableProfilePicturesCache", isOn: $disableProfilePicturesCache)
            .help(Text("settings.toggle.disableProfilePicturesCache.help"))

        Toggle("settings.toggle.disableProfileCache", isOn: $disableProfileCache)
            .help(Text("settings.toggle.disableProfileCache.help"))

        HStack {
            Button(role: .destructive) {
                CacheService.shared.clearAllCaches()
            } label: {
                Text("settings.button.clearCache")
            }

            Spacer()

            Text(CacheService.shared.getCacheSizeString())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func privacySettings() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            /*
            Picker("settings.privacy.mode", selection: $privacyModeRawValue) {
                ForEach(PrivacyMode.allCases) { mode in
                    Text(mode.titleKey).tag(mode.rawValue)
                }
            }
            #if os(iOS)
            .pickerStyle(.segmented)
            #endif
            */

            VStack(alignment: .leading, spacing: 12) {
                ForEach(PrivacyMode.allCases) { mode in
                    privacyModeOption(for: mode)
                }
            }

            if currentPrivacyMode == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Load Discord Emojis", isOn: $privacyCustomLoadEmojis)

                    Text("Turn this off to exclusively use Stossycord custom emojis.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .onAppear(perform: ensureValidPrivacyMode)
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

    private func refreshCustomEmojiManagerConfiguration() {
        customEmojiManager.configure(
            enabled: customEmojiStorageEnabled,
            storeID: customEmojiStoreID,
            token: customEmojiBlobToken
        )
    }

    @ViewBuilder
    private func betaSettings() -> some View {
        Toggle("settings.toggle.hideRestrictedChannels", isOn: $hideRestrictedChannels)
            .help(Text("settings.toggle.hideRestrictedChannels.help"))

        Toggle("settings.toggle.useNativePicker", isOn: $useNativePicker)
            .help(Text("settings.toggle.useNativePicker.help"))

        Toggle("settings.toggle.useRedesignedMessages", isOn: $useRedesignedMessages)
            .help(Text("settings.toggle.useRedesignedMessages.help"))

        Toggle("settings.toggle.useDiscordFolders", isOn: $useDiscordFolders)
            .help(Text("settings.toggle.useDiscordFolders.help"))
    }

    @ViewBuilder
    private func presenceSettings() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("settings.presence.appleMusicAccess")
                Spacer()
                Text(authorizationStatusText(presenceManager.authorizationStatus))
                    .foregroundColor(authorizationStatusColor(presenceManager.authorizationStatus))
                    .font(.subheadline)
            }

            if presenceManager.authorizationStatus != .authorized {
                Button {
                    presenceManager.requestAuthorization()
                } label: {
                    if presenceManager.isRequestingAuthorization {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("settings.presence.requestAccess")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(presenceManager.isRequestingAuthorization)
            } else {
                Text("settings.presence.enabled")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if presenceManager.authorizationStatus == .authorized {
                Toggle("settings.presence.shareStatus", isOn: $presenceManager.musicPresenceEnabled)
            } else {
                Text(authorizationHelpText(for: presenceManager.authorizationStatus))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !presenceManager.musicPresenceEnabled {
                Divider()

                Text("settings.presence.customPresence")
                    .font(.headline)

                TextField("settings.presence.activityName", text: $presenceManager.customPresenceName)
                TextField("settings.presence.details", text: $presenceManager.customPresenceDetails)
                TextField("settings.presence.state", text: $presenceManager.customPresenceState)

                Text("settings.presence.clearInstructions")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !presenceManager.customPresenceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !presenceManager.customPresenceDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !presenceManager.customPresenceState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(role: .destructive) {
                        presenceManager.customPresenceName = ""
                        presenceManager.customPresenceDetails = ""
                        presenceManager.customPresenceState = ""
                    } label: {
                        Text("settings.presence.clearButton")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func tokenSettings() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Text("settings.token.label")
                    .font(.headline)

                Spacer()

                tokenDisplay
            }

            Divider()

            if #available(iOS 26.0, *) {
                Button(role: .destructive) {
                    keychain.delete("token")
                    showAlert = true
                } label: {
                    Text("settings.button.logout")
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)
                .glassEffect(.clear.tint(.red).interactive())
                .foregroundColor(.white)
            } else {
                Button(role: .destructive) {
                    keychain.delete("token")
                    showAlert = true
                } label: {
                    Text("settings.button.logout")
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                )
                .foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
    }

    private var tokenDisplay: some View {
        Group {
            if isspoiler {
                HStack {
                    Button(action: authenticate) {
                        Image(systemName: "lock.rectangle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            } else {
                let token = keychain.get("token") ?? ""
                Text(token.isEmpty ? "—" : token)
                    .font(.system(.body, design: .monospaced))
                    .contextMenu {
                        Button {
                            #if os(macOS)
                            if let token = keychain.get("token") {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(token, forType: .string)
                            }
                            #else
                            UIPasteboard.general.string = keychain.get("token") ?? ""
                            #endif
                        } label: {
                            Text("common.copy")
                        }
                    }
                    .onTapGesture {
                        isspoiler = true
                    }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 0)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(groupedBackgroundColor)
        )
    }

    @ViewBuilder
    private func destructiveSettings() -> some View {
        Toggle("settings.toggle.allowDestructiveActions", isOn: Binding(
            get: { allowDestructiveActions },
            set: { newValue in
                if newValue {
                    showPopover = true
                } else {
                    allowDestructiveActions = false
                }
            }
        ))
        .help(Text("settings.toggle.allowDestructiveActions.help"))
        .foregroundColor(allowDestructiveActions ? .red : .primary)
    }

    private var destructiveConfirmation: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.yellow)
                    .padding(.vertical, 16)

                Text("settings.destructive.confirmTitle")
                    .font(.system(size: 38, weight: .bold))

                Text("settings.destructive.confirmDescription")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 600, alignment: .leading)
            }
            .padding(.horizontal, 34)

            Spacer()

            VStack(spacing: 12) {
                if #available(iOS 26.0, *) {
                    Button(action: {
                        allowDestructiveActions = true
                        showPopover = false
                    }) {
                        Text("common.enable")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .glassEffect(.regular)

                    Button(action: {
                        allowDestructiveActions = false
                        showPopover = false
                    }) {
                        Text("common.nevermind")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .glassEffect(.regular)
                } else {
                    Button(action: {
                        allowDestructiveActions = true
                        showPopover = false
                    }) {
                        Text("common.enable")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button(action: {
                        allowDestructiveActions = false
                        showPopover = false
                    }) {
                        Text("common.nevermind")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
        .background {
            #if canImport(UIKit)
            Color(UIColor.systemBackground)
            #elseif canImport(AppKit)
            Color(NSColor.windowBackgroundColor)
            #else
            Color(.clear)
            #endif
        }
        #if !os(iOS)
        .frame(maxHeight: .infinity)
        #endif
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check whether biometric authentication is possible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // It's possible, so go ahead and use it
            let reason = String(localized: "settings.auth.biometricReason")

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isspoiler = false
                    } else {
                        // Handle authentication errors
                        if let error = authenticationError as? LAError {
                            switch error.code {
                            case .userFallback:
                                // User chose to use fallback authentication (e.g., passcode)
                                self.authenticateWithPasscode()
                            case .biometryNotAvailable, .biometryNotEnrolled:
                                // Biometric authentication is not available or not set up
                                self.authenticateWithPasscode()
                            default:
                                print("Authentication failed: \(error.localizedDescription)")
                                self.isspoiler = true
                            }
                        }
                    }
                }
            }
        } else {
            // Biometric authentication is not available
            authenticateWithPasscode()
        }
    }

    func authenticateWithPasscode() {
        let context = LAContext()
        let reason = String(localized: "settings.auth.passcodeReason")

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isspoiler = false
                } else {
                    let fallback = String(localized: "settings.auth.unknownError")
                    print("Passcode authentication failed: \(error?.localizedDescription ?? fallback)")
                    self.isspoiler = true
                }
            }
        }
    }
}

private extension SettingsView {
    func ensureValidMessageStyle() {
        guard let style = MessageBubbleStyle(rawValue: messageStyleRawValue) else {
            messageStyleRawValue = MessageBubbleStyle.imessage.rawValue
            return
        }

        if style == .default {
            messageStyleRawValue = MessageBubbleStyle.imessage.rawValue
        }
    }

    func ensureValidPrivacyMode() {
        guard PrivacyMode(rawValue: privacyModeRawValue) != nil else {
            privacyModeRawValue = PrivacyMode.defaultMode.rawValue
            return
        }
    }

    @ViewBuilder
    func privacyModeOption(for mode: PrivacyMode) -> some View {
        let isSelected = mode == currentPrivacyMode

        Button {
            privacyModeRawValue = mode.rawValue
        } label: {
            PrivacyModeOptionRow(
                mode: mode,
                isSelected: isSelected,
                backgroundColor: groupedBackgroundColor
            )
        }
        .buttonStyle(.plain)
    }
}

private extension SettingsView {
    func authorizationStatusText(_ status: MusicAuthorization.Status) -> LocalizedStringKey {
        switch status {
        case .authorized:
            return "authorization.status.authorized"
        case .denied:
            return "authorization.status.denied"
        case .restricted:
            return "authorization.status.restricted"
        case .notDetermined:
            return "authorization.status.notRequested"
        @unknown default:
            return "authorization.status.unknown"
        }
    }

    func authorizationStatusColor(_ status: MusicAuthorization.Status) -> Color {
        switch status {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .restricted:
            return .orange
        case .notDetermined:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    func authorizationHelpText(for status: MusicAuthorization.Status) -> LocalizedStringKey {
        switch status {
        case .authorized:
            return "settings.presence.enabled"
        case .notDetermined:
            return "settings.presence.help.request"
        case .denied:
            return "settings.presence.help.denied"
        case .restricted:
            return "settings.presence.help.restricted"
        @unknown default:
            return "settings.presence.help.unavailable"
        }
    }
}

private struct PrivacyModeOptionRow: View {
    let mode: PrivacyMode
    let isSelected: Bool
    let backgroundColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: mode.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mode.titleKey)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text(mode.descriptionKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : backgroundColor)
        )
    }
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

#Preview {
    SettingsView()
        .environmentObject(PresenceManager(webSocketService: WebSocketService.shared))
}

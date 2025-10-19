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
    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true
    @AppStorage("useSquaredAvatars") private var useSquaredAvatars: Bool = false
    @StateObject private var themeManager = ThemeManager()
    @State private var isPresentingThemeEditor = false
    @State private var themeEditorExistingTheme: MessageTheme?
    @State private var themeEditorBaseTheme: MessageTheme?
    @State private var showingThemeTemplatePicker = false
    @State private var themePendingDeletion: MessageTheme?
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
    @AppStorage("useSettingsTabLabel") private var useSettingsTabLabel: Bool = true

    @StateObject private var customEmojiManager = CustomEmojiManager()
    @State private var showingEmojiImporter: Bool = false
    @State private var emojiPendingDeletion: VercelBlobService.Emoji?
    @State private var editingEmoji: VercelBlobService.Emoji?
    @State private var editingName: String = ""
    
    private enum SettingsDestination: String, CaseIterable, Hashable {
        case general
        case appearance
        case messageTypes
        case themes
        case cache
        case privacy
        case customEmojis
        case beta
        case presence
        case token
        case warningZone

        var titleKey: LocalizedStringKey {
            switch self {
                case .general: return "General"
                case .appearance: return "settings.section.appearance"
                case .messageTypes: return "Message Types"
                case .themes: return "Message Themes"
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
                case .general: return "gear"
                case .appearance: return "paintbrush"
                case .messageTypes: return "checkmark.circle"
                case .themes: return "bubble.left.and.bubble.right"
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

                Section {
                    NavigationLink(value: SettingsDestination.general) {
                        sectionRow(for: .general)
                    }

                    NavigationLink(value: SettingsDestination.appearance) {
                        sectionRow(for: .appearance)
                    }

                    NavigationLink(value: SettingsDestination.messageTypes) {
                        sectionRow(for: .messageTypes)
                    }

                    NavigationLink(value: SettingsDestination.themes) {
                        sectionRow(for: .themes)
                    }

                    ForEach(SettingsDestination.allCases.filter { $0 != .appearance && $0 != .themes && $0 != .messageTypes && $0 != .general }, id: \.self) { destination in
                        NavigationLink(value: destination) {
                            sectionRow(for: destination)
                        }
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
        case .general:
            settingsSection(for: destination) {
                generalSettings()
            }
        case .appearance:
            settingsSection(for: destination) {
                appearanceSettings()
            }

        case .messageTypes:
            MessageTypesSettingsView()

        case .themes:
            themesSettings()

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
    private func generalSettings() -> some View {
        Toggle("settings.toggle.useSettingsTabLabel", isOn: $useSettingsTabLabel)
            .help(Text("settings.toggle.useSettingsTabLabel.help"))
    }

    @ViewBuilder
    private func appearanceSettings() -> some View {
        Toggle("settings.toggle.disableAnimatedAvatars", isOn: $disableAnimatedAvatars)
            .help(Text("settings.toggle.disableAnimatedAvatars.help"))

        Toggle("settings.toggle.disableProfilePictureTap", isOn: $disableProfilePictureTap)
            .help(Text("settings.toggle.disableProfilePictureTap.help"))

        Toggle("settings.toggle.showSelfAvatar", isOn: $showSelfAvatar)
            .help(Text("settings.toggle.showSelfAvatar.help"))

        Toggle("Squared avatars", isOn: $useSquaredAvatars)
            .help(Text("minecraft avatars fr"))
    }

    @ViewBuilder
    private func themesSettings() -> some View {
        List {
            Section(
                header: Text("Active Theme")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary),
                footer: Text("Select a theme or create your own. Your choice will be saved.")
                    .font(.footnote)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(themeManager.selectedTheme.name)
                        .font(.headline)
                    if let description = themeManager.selectedTheme.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)

                ThemePreviewView(theme: themeManager.selectedTheme, websocketService: WebSocketService.shared)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground({
                        if let bgColor = themeManager.selectedTheme.chatBackgroundColor, !bgColor.isEmpty {
                            Color(hex: bgColor)
                        } else {
                            Color.clear
                        }
                    }())
                    .animation(.easeInOut(duration: 0.3), value: themeManager.selectedTheme.chatBackgroundColor)
                    .listRowSeparator(.hidden)

                Button {
                    showingThemeTemplatePicker = true
                } label: {
                    Label("Create Custom Theme", systemImage: "plus")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.top, 8)
            }

            Section(
                header: Text("Built-in Themes")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            ) {
                ForEach(MessageTheme.builtInThemes, id: \.id) { theme in
                    themeRow(for: theme, isCustom: false)
                }
            }

            Section(
                header: Text("Custom Themes")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary),
                footer: customThemesFooter
            ) {
                if themeManager.customThemes.isEmpty {
                    Text("You haven't created any custom themes yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(themeManager.customThemes, id: \.id) { theme in
                        themeRow(for: theme, isCustom: true)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(SettingsDestination.themes.titleKey)
        .sheet(isPresented: $showingThemeTemplatePicker) {
            NavigationStack {
                ThemeTemplatePickerView(themeManager: themeManager, websocketService: WebSocketService.shared)
            }
        }
        .fullScreenCover(isPresented: $isPresentingThemeEditor) {
            NavigationStack {
                CustomThemeEditorView(
                    themeManager: themeManager,
                    existingTheme: themeEditorExistingTheme,
                    baseTheme: themeEditorBaseTheme,
                    websocketService: WebSocketService.shared
                )
            }
            .onDisappear {
                themeEditorExistingTheme = nil
                themeEditorBaseTheme = nil
            }
        }
        .confirmationDialog(
            "Delete theme?",
            isPresented: Binding(
                get: { themePendingDeletion != nil },
                set: { newValue in
                    if !newValue {
                        themePendingDeletion = nil
                    }
                }
            ),
            presenting: themePendingDeletion
        ) { theme in
            Button("Delete \(theme.name)", role: .destructive) {
                themeManager.deleteCustomTheme(theme)
                themePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                themePendingDeletion = nil
            }
        } message: { theme in
            Text("This will remove the custom theme \(theme.name). This action cannot be undone.")
        }
    }

    private var customThemesFooter: some View {
        Text("Swipe or long-press a theme to edit, duplicate, or delete it.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func themeRow(for theme: MessageTheme, isCustom: Bool) -> some View {
        let isSelected = themeManager.selectedTheme.id == theme.id

        Button {
            themeManager.selectTheme(theme)
        } label: {
            HStack(spacing: 12) {
                ThemeListLabel(theme: theme, iconColor: isSelected ? .accentColor : .secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            themeContextMenu(for: theme, isCustom: isCustom)
        }
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isCustom {
                Button {
                    beginEditing(theme)
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.3")
                }
                .tint(.blue)

                Button {
                    duplicateTheme(theme)
                } label: {
                    Label("Duplicate", systemImage: "square.on.square")
                }
                .tint(.orange)

                Button(role: .destructive) {
                    requestDelete(theme)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button {
                    duplicateTheme(theme)
                } label: {
                    Label("Duplicate", systemImage: "square.on.square")
                }
                .tint(.orange)
            }
        }
        #endif
    }

    @ViewBuilder
    private func themeContextMenu(for theme: MessageTheme, isCustom: Bool) -> some View {
        Button {
            duplicateTheme(theme)
        } label: {
            Label("Duplicate", systemImage: "square.on.square")
        }

        if isCustom {
            Button {
                beginEditing(theme)
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }

            Button(role: .destructive) {
                requestDelete(theme)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func beginEditing(_ theme: MessageTheme) {
        themeEditorExistingTheme = theme
        themeEditorBaseTheme = nil
        DispatchQueue.main.async {
            isPresentingThemeEditor = true
        }
    }

    private func duplicateTheme(_ theme: MessageTheme) {
        themeEditorExistingTheme = nil
        themeEditorBaseTheme = theme
        DispatchQueue.main.async {
            isPresentingThemeEditor = true
        }
    }

    private func requestDelete(_ theme: MessageTheme) {
        themePendingDeletion = theme
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

private struct MessageTypesSettingsView: View {
    @AppStorage("visibleMessageTypeIDs") private var visibleMessageTypeIDsData: Data?

    private let excludedTypeIDs: Set<Int> = [0, 19]

    private var customizableTypeIDs: Set<Int> { MessageType.customizableIDs }

    private var orderedMessageTypes: [MessageType] {
        let customizable = messageTypes
            .filter { customizableTypeIDs.contains($0.id) && !excludedTypeIDs.contains($0.id) }
            .sorted { formattedName(for: $0).localizedCaseInsensitiveCompare(formattedName(for: $1)) == .orderedAscending }

        let nonCustomizable = messageTypes
            .filter { !customizableTypeIDs.contains($0.id) && !excludedTypeIDs.contains($0.id) }
            .sorted { formattedName(for: $0).localizedCaseInsensitiveCompare(formattedName(for: $1)) == .orderedAscending }

        return customizable + nonCustomizable
    }

    private var visibleMessageTypeIDs: Set<Int> {
        guard let data = visibleMessageTypeIDsData,
              let decoded = try? JSONDecoder().decode([Int].self, from: data) else {
            return customizableTypeIDs
        }
        return Set(decoded).intersection(customizableTypeIDs)
    }

    var body: some View {
        List {
            Section(header: Text("Available")) {
                ForEach(availableTypes, id: \.id) { type in
                    messageTypeToggle(for: type)
                }
            }

            Section(header: Text("Unavailable"), footer: footerText) {
                Text("These message types aren't currently supported and will not be shown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                ForEach(unavailableTypes, id: \.id) { type in
                    messageTypeToggle(for: type)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Message Types")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var availableTypes: [MessageType] {
        orderedMessageTypes.filter { customizableTypeIDs.contains($0.id) }
    }

    private var unavailableTypes: [MessageType] {
        orderedMessageTypes.filter { !customizableTypeIDs.contains($0.id) }
    }

    private func messageTypeToggle(for type: MessageType) -> some View {
        let isCustomizable = customizableTypeIDs.contains(type.id)

        return Toggle(isOn: binding(for: type, isCustomizable: isCustomizable)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedName(for: type))
                    .font(.body)
                if !type.description.isEmpty {
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!isCustomizable)
        #if os(macOS)
        .toggleStyle(.checkbox)
        #endif
    }

    private func binding(for type: MessageType, isCustomizable: Bool) -> Binding<Bool> {
        Binding(
            get: {
                guard isCustomizable else { return false }
                return visibleMessageTypeIDs.contains(type.id)
            },
            set: { newValue in
                guard isCustomizable else { return }
                setMessageTypeVisibility(for: type.id, isVisible: newValue)
            }
        )
    }

    private func setMessageTypeVisibility(for id: Int, isVisible: Bool) {
        var updated = visibleMessageTypeIDs
        if isVisible {
            updated.insert(id)
        } else {
            updated.remove(id)
        }
        saveVisibleMessageTypeIDs(updated)
    }

    private func saveVisibleMessageTypeIDs(_ ids: Set<Int>) {
        let filtered = Array(ids.intersection(customizableTypeIDs))
        visibleMessageTypeIDsData = try? JSONEncoder().encode(filtered)
    }

    private func formattedName(for type: MessageType) -> String {
        type.name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    @ViewBuilder
    private var footerText: some View {
        Text("Only message types with custom rendering can be toggled. Others are shown by default.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
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

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
    @AppStorage("allowDestructiveActions") private var allowDestructiveActions: Bool = false
    
    var body: some View {
        VStack {
            Text("settings.title")
                .font(.largeTitle)
                .padding()
            
            List {
                Section("settings.section.appearance") {
                    Toggle("settings.toggle.disableAnimatedAvatars", isOn: $disableAnimatedAvatars)
                        .help(Text("settings.toggle.disableAnimatedAvatars.help"))
                    Toggle("settings.toggle.disableProfilePictureTap", isOn: $disableProfilePictureTap)
                        .help(Text("settings.toggle.disableProfilePictureTap.help"))
                }

                Section("settings.section.design") {
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
                                .foregroundColor(.secondary)
                            TextEditor(text: $customBubbleJSON)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 160)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                    #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                    #endif
                            if !MessageBubbleVisualConfiguration.isCustomJSONValid(customBubbleJSON) {
                                Text("settings.customBubble.invalid")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            HStack(spacing: 12) {
                                Button("settings.customBubble.loadSample") {
                                    customBubbleJSON = MessageBubbleVisualConfiguration.sampleJSON
                                }
                                Button("common.clear") {
                                    customBubbleJSON = ""
                                }
                                .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding(.top, 4)
                    }
                }
                
                Section("settings.section.cache") {
                    Toggle("settings.toggle.disableProfilePicturesCache", isOn: $disableProfilePicturesCache)
                        .help(Text("settings.toggle.disableProfilePicturesCache.help"))
                    Toggle("settings.toggle.disableProfileCache", isOn: $disableProfileCache)
                        .help(Text("settings.toggle.disableProfileCache.help"))
                    
                    HStack {
                        Button("settings.button.clearCache") {
                            CacheService.shared.clearAllCaches()
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Text(CacheService.shared.getCacheSizeString())
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("settings.section.beta") {
                    Toggle("settings.toggle.hideRestrictedChannels", isOn: $hideRestrictedChannels)
                        .help(Text("settings.toggle.hideRestrictedChannels.help"))
                    Toggle("settings.toggle.useNativePicker", isOn: $useNativePicker)
                        .help(Text("settings.toggle.useNativePicker.help"))
                    Toggle("settings.toggle.useRedesignedMessages", isOn: $useRedesignedMessages)
                        .help(Text("settings.toggle.useRedesignedMessages.help"))
                    Toggle("settings.toggle.useDiscordFolders", isOn: $useDiscordFolders)
                        .help(Text("settings.toggle.useDiscordFolders.help"))
                }

                Section("settings.section.presence") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
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
                                .foregroundColor(.secondary)
                        }

                        if presenceManager.authorizationStatus == .authorized {
                            Toggle("settings.presence.shareStatus", isOn: $presenceManager.musicPresenceEnabled)
                        } else {
                            Text(authorizationHelpText(for: presenceManager.authorizationStatus))
                                .font(.footnote)
                                .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)

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

                Section("settings.section.token") {
                    
                    HStack {
                        Text("settings.token.label")
                        ZStack {
                            if isspoiler {
                                Spacer()
                                Image(systemName: "lock.rectangle")
                                    .onTapGesture {
                                        if isspoiler {
                                            authenticate()
                                        } else {
                                            isspoiler = true
                                        }
                                    }
                                Spacer()
                            } else {
                                Text(keychain.get("token") ?? "")
                                    .contextMenu {
                                        Button {
                                            #if os(macOS)
                                            if let token = keychain.get("token") {
                                                let pasteboard = NSPasteboard.general
                                                pasteboard.clearContents() // Clear the pasteboard before writing
                                                pasteboard.setString(token, forType: .string)
                                            } else {
                                                print("No token found in the keychain.")
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
                                        // token = ""
                                    }
                            }
                        }
                    }
                    
                    
                    ZStack {
                        Button {
                            keychain.delete("token")
                            showAlert = true
                        } label: {
                            Text("settings.button.logout")
                        }
                    }
                }

                Section("settings.section.warningZone") {
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
                    .sheet(isPresented: $showPopover) {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 24) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.yellow)
                                    .padding(.top, 16)
                                    .padding(.bottom, 16)

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
                        .background(Color(UIColor.systemBackground))
                        /*.presentationDetents {
                            if #available(iOS 16.0, *) {
                                [.fraction(0.5), .large]
                            } else {
                                []
                            }
                        } */
                        #if !os(iOS)
                        .frame(maxHeight: .infinity)
                        #endif
                    }
                }

                /*
                if let token = keychain.get("token") {
                    Section("Servers") {
                        HStack {
                            Text("Join Server: ")
                            
                            TextField("Discord Invite Link", text: $guildID)
                                .onSubmit {
                                    if let inviteID = GetInviteId(from: guildID) {
                                        GetServerID(token: token, inviteID: inviteID) { invite in
                                            print(invite)
                                            if let invite {
                                                joinDiscordGuild(token: token, guildId: invite) { response in
                                                    if response == nil {
                                                        print("Server already joined")
                                                    } else {
                                                        print(response)
                                                    }
                                                }
                                            }
                                        }
                                        
                                    }
                                }
                            
                        }
                    }
                }
                 */
            }
            .alert(isPresented: $showAlert) {
                .init(
                    title: Text("settings.alert.tokenResetTitle"),
                    message: Text("settings.alert.tokenResetMessage"))
            }
            .onAppear {
                presenceManager.refreshAuthorizationStatus()
            }
        }
        .onAppear {
            ensureValidMessageStyle()
        }
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
                    print("Passcode authentication failed: \(error?.localizedDescription ?? fallback)\")
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

#Preview {
    SettingsView()
        .environmentObject(PresenceManager(webSocketService: WebSocketService.shared))
}

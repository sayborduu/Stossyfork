//
//  ProfileView.swift
//  Stossycord
//
//  Created by Alex Badi on 16/10/25.
//

import SwiftUI
import MarkdownUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ProfileView: View {
    @ObservedObject var webSocketService: WebSocketService
    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    @EnvironmentObject private var presenceManager: PresenceManager
    @State private var isShowingSettings = false
    @State private var navigateToSettings = false
    @State private var extendedUserProfile: UserProfile?
    @State private var hasLoadedProfile = false
    
    private let privacyHelper = EmojiPrivacyHelper()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading profile...")
                    } else if let profile = userProfile {
                        VStack(spacing: 16) {
                            if let avatarURL = profile.avatarUrl {
                                CachedAsyncImage(url: URL(string: avatarURL)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(profile.user.username.prefix(1).uppercased())
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                    )
                            }

                            VStack(spacing: 4) {
                                Text(profile.displayName)
                                    .font(.title2.weight(.semibold))

                                Text(profile.userTag)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 20)

                        if let bio = bio(for: profile) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bio")
                                    .font(.headline)

                                bioContent(bio)
                                    .font(.body)
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(bioBackgroundColor)
                            )
                            .padding(.horizontal)
                        }

                        if let customStatus = webSocketService.userSettings?.customStatus?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !customStatus.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom Status")
                                    .font(.headline)

                                customStatusContent(customStatus)
                                    .font(.callout)
                                    .lineSpacing(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(bioBackgroundColor)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Premium Info
                        if let premiumType = profile.user.premiumType, premiumType > 0 {
                            VStack(spacing: 0) {
                                Section {
                                    VStack(spacing: 0) {
                                        InfoRow(title: "Nitro Type", value: premiumTypeString(premiumType))
                                        
                                        if let premiumSince = profile.premiumSince {
                                            Divider().padding(.leading, 16)
                                            InfoRow(title: "Member Since", value: formatDate(premiumSince))
                                        }
                                    }
                                } header: {
                                    Text("Premium")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)
                                }
                            }
                            .background(bioBackgroundColor)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // User Settings Section
                        if let settings = webSocketService.userSettings {
                            VStack(spacing: 0) {
                                Section {
                                    VStack(spacing: 0) {
                                        if let theme = settings.theme {
                                            InfoRow(title: "Theme", value: theme.capitalized)
                                            Divider().padding(.leading, 16)
                                        }
                                        
                                        if let locale = settings.locale {
                                            InfoRow(title: "Language", value: locale)
                                            Divider().padding(.leading, 16)
                                        }
                                        
                                        if let status = settings.status {
                                            InfoRow(title: "Status", value: status.capitalized)
                                            Divider().padding(.leading, 16)
                                        }
                                        
                                        if let developerMode = settings.developerMode {
                                            InfoRow(title: "Developer Mode", value: developerMode ? "Enabled" : "Disabled")
                                        }
                                    }
                                } header: {
                                    Text("Discord Settings")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)
                                }
                            }
                            .background(bioBackgroundColor)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        /*
                        VStack(spacing: 0) {
                            // Account info
                            Section {
                                VStack(spacing: 12) {
                                    if let email = profile.user.email {
                                        ProfileRow(title: "Email", value: email)
                                    }
                                }
                            } header: {
                                Text("Account")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)
                            }
                            
                            // Premium info
                            if let premiumType = profile.premiumType, premiumType > 0 {
                                Section {
                                    VStack(spacing: 12) {
                                        ProfileRow(title: "Nitro", value: premiumType == 2 ? "Nitro" : "Classic")
                                        
                                        if let since = profile.premiumSince {
                                            ProfileRow(title: "Since", value: since)
                                        }
                                    }
                                } header: {
                                    Text("Premium")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.top, 20)
                                        .padding(.bottom, 8)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        */
                    } else {
                        Text("Failed to load profile")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !hasLoadedProfile {
                    loadProfile()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
                    .environmentObject(presenceManager)
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(presenceManager)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    isShowingSettings = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func loadProfile() {
        isLoading = true
        
        let currentUser = webSocketService.currentUser
        
        let basicProfile = UserProfile(
            user: currentUser,
            connectedAccounts: nil,
            premiumSince: nil,
            premiumType: currentUser.premiumType,
            premiumGuildSince: nil,
            profileThemesExperimentBucket: nil,
            mutualGuilds: nil,
            mutualFriends: nil,
            userProfile: nil
        )

        print("============ USER BASIC PROFILE ============")
        print("User ID: \(currentUser.id)")
        print("Username: \(currentUser.username)")
        print("Global Name: \(currentUser.globalName ?? "N/A")")
        print("Email: \(currentUser.email ?? "N/A")")
        print("Bio: \(currentUser.bio ?? "N/A")")
        print("Premium Type: \(currentUser.premiumType ?? 0)")
        print("============ END USER BASIC PROFILE ============")

        userProfile = basicProfile
        
        getUserProfile(token: webSocketService.token, userId: currentUser.id) { extendedProfile in
            DispatchQueue.main.async {
                if let extended = extendedProfile {
                    print("============ EXTENDED USER PROFILE ============")
                    print("Connected Accounts: \(extended.connectedAccounts?.count ?? 0)")
                    print("Mutual Guilds: \(extended.mutualGuilds?.count ?? 0)")
                    print("Premium Since: \(extended.premiumSince ?? "N/A")")
                    print("User Profile Bio: \(extended.userProfile?.bio ?? "N/A")")
                    print("============ END EXTENDED USER PROFILE ============")
                    
                    self.extendedUserProfile = extended
                    
                    let mergedProfile = UserProfile(
                        user: currentUser,
                        connectedAccounts: extended.connectedAccounts,
                        premiumSince: extended.premiumSince,
                        premiumType: extended.premiumType ?? currentUser.premiumType,
                        premiumGuildSince: extended.premiumGuildSince,
                        profileThemesExperimentBucket: extended.profileThemesExperimentBucket,
                        mutualGuilds: extended.mutualGuilds,
                        mutualFriends: extended.mutualFriends,
                        userProfile: extended.userProfile
                    )
                    self.userProfile = mergedProfile
                }
                self.isLoading = false
                self.hasLoadedProfile = true
            }
        }
    }

    private func bio(for profile: UserProfile) -> String? {
        let candidates = [profile.userProfile?.bio, profile.user.bio]
        for candidate in candidates {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed.replacingOccurrences(of: "\n", with: "  \n")
            }
        }
        return nil
    }

    private func markdownBio(from bio: String) -> String {
        CustomEmojiRenderer.markdownString(from: bio)
    }
    
    @ViewBuilder
    private func bioContent(_ bio: String) -> some View {
        if privacyHelper.shouldRenderEmojiImages(for: bio) {
            Markdown(markdownBio(from: bio))
                .markdownTheme(.basic)
                .markdownImageProvider(DiscordEmojiImageProvider(lineHeight: bioLineHeight))
                .markdownInlineImageProvider(DiscordEmojiInlineImageProvider(lineHeight: bioLineHeight))
        } else {
            Markdown(privacyHelper.replaceEmojisInContent(bio))
                .markdownTheme(.basic)
        }
    }
    
    @ViewBuilder
    private func customStatusContent(_ status: String) -> some View {
        if privacyHelper.shouldRenderEmojiImages(for: status) {
            Markdown(CustomEmojiRenderer.markdownString(from: status))
                .markdownTheme(.basic)
                .markdownImageProvider(DiscordEmojiImageProvider(lineHeight: statusLineHeight))
                .markdownInlineImageProvider(DiscordEmojiInlineImageProvider(lineHeight: statusLineHeight))
        } else {
            Markdown(privacyHelper.replaceEmojisInContent(status))
                .markdownTheme(.basic)
        }
    }

    private var bioLineHeight: CGFloat {
        #if os(iOS)
        UIFont.preferredFont(forTextStyle: .body).lineHeight
        #elseif os(macOS)
        NSFont.preferredFont(forTextStyle: .body).boundingRectForFont.size.height
        #else
        18
        #endif
    }

    private var statusLineHeight: CGFloat {
        #if os(iOS)
        UIFont.preferredFont(forTextStyle: .caption1).lineHeight
        #elseif os(macOS)
        NSFont.preferredFont(forTextStyle: .caption1).boundingRectForFont.size.height
        #else
        14
        #endif
    }

    private var bioBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
    private func premiumTypeString(_ type: Int) -> String {
        switch type {
        case 1:
            return "Nitro Classic"
        case 2:
            return "Nitro"
        case 3:
            return "Nitro Basic"
        default:
            return "None"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return dateString
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ProfileRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
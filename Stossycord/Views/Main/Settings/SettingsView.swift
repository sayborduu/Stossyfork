//
//  SettingsView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum SettingsDestination: String, CaseIterable, Hashable {
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

struct SettingsView: View {
    @EnvironmentObject private var presenceManager: PresenceManager

    @ViewBuilder
    private func settingsSection<Content: View>(for destination: SettingsDestination, @ViewBuilder content: () -> Content) -> some View {
        SettingsSection(
            title: destination.titleKey,
            description: destination.detailDescriptionKey,
            content: content
        )
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
        .onAppear {
            presenceManager.refreshAuthorizationStatus()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: SettingsDestination) -> some View {
        switch destination {
        case .general:
            settingsSection(for: destination) {
                GeneralSettings(groupedBackgroundColor: groupedBackgroundColor)
            }
        case .appearance:
            settingsSection(for: destination) {
                AppearanceSettings()
            }

        case .messageTypes:
            MessageTypesSettingsView()

        case .themes:
            ThemeSettings()

        case .cache:
            settingsSection(for: destination) {
                CacheSettings()
            }

        case .privacy:
            PrivacySettings(destination: destination, groupedBackgroundColor: groupedBackgroundColor)

        case .customEmojis:
            CustomEmojiViewSettings(destination: destination)

        case .beta:
            settingsSection(for: destination) {
                BetaSettings()
            }

        case .presence:
            settingsSection(for: destination) {
                PresenceSettings()
            }

        case .token:
            settingsSection(for: destination) {
                TokenSettings(groupedBackgroundColor: groupedBackgroundColor)
            }

        case .warningZone:
            settingsSection(for: destination) {
                DestructiveSettings()
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
            AppIcon()
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

    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemGroupedBackground)
        #endif
    }

    // MARK: - Settings Sections

}

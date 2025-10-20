//
//  Privacy.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/2025.
//

import SwiftUI

struct PrivacySettings: View {
    @AppStorage("privacyMode") private var privacyModeRawValue: String = PrivacyMode.defaultMode.rawValue
    @AppStorage("privacyCustomLoadEmojis") private var privacyCustomLoadEmojis: Bool = true
    @AppStorage("discordEmojiReplacement") private var discordEmojiReplacement: String = ""
    
    @State private var destination: SettingsDestination
    @State private var groupedBackgroundColor: Color

    init(destination: SettingsDestination, groupedBackgroundColor: Color) {
        _destination = State(initialValue: destination)
        _groupedBackgroundColor = State(initialValue: groupedBackgroundColor)
    }

    private var currentPrivacyMode: PrivacyMode {
        PrivacyMode(rawValue: privacyModeRawValue) ?? PrivacyMode.defaultMode
    }

    var body: some View {
        List {
            Section(header: Text("Privacy Modes")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)) {
                lprivacySettings()
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
    }

    @ViewBuilder
    private func lprivacySettings() -> some View {
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
}

private extension PrivacySettings {
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
//
//  Presence.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/2025.
//

import SwiftUI
import MusicKit

struct PresenceSettings: View {
    @EnvironmentObject private var presenceManager: PresenceManager
    
    var body: some View {
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
}

private extension PresenceSettings {
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
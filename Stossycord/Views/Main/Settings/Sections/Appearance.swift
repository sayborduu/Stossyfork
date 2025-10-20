//
//  Appearance.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/25.
//

import SwiftUI

struct AppearanceSettings: View {
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    @AppStorage("useDiscordFolders") private var useDiscordFolders: Bool = true
    @AppStorage("useNativePicker") private var useNativePicker: Bool = true
    
    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true
    
    var body: some View {
        Toggle("settings.toggle.disableAnimatedAvatars", isOn: $disableAnimatedAvatars)
            .help(Text("settings.toggle.disableAnimatedAvatars.help"))

        Toggle("settings.toggle.disableProfilePictureTap", isOn: $disableProfilePictureTap)
            .help(Text("settings.toggle.disableProfilePictureTap.help"))

        Toggle("settings.toggle.showSelfAvatar", isOn: $showSelfAvatar)
            .help(Text("settings.toggle.showSelfAvatar.help"))

        Toggle("settings.toggle.useDiscordFolders", isOn: $useDiscordFolders)
            .help(Text("settings.toggle.useDiscordFolders.help"))

        Toggle("settings.toggle.useNativePicker", isOn: $useNativePicker)
            .help(Text("settings.toggle.useNativePicker.help"))
    }
}
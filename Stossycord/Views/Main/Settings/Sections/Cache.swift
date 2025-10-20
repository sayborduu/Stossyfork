//
//  Cache.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/25.
//

import SwiftUI

struct CacheSettings: View {
    @AppStorage("disableProfilePicturesCache") private var disableProfilePicturesCache: Bool = false
    @AppStorage("disableProfileCache") private var disableProfileCache: Bool = false
    
    var body: some View {
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
}
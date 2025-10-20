//
//  Beta.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/25.
//

import SwiftUI

struct BetaSettings: View {
    @AppStorage("hideRestrictedChannels") private var hideRestrictedChannels: Bool = false

    var body: some View {
        Toggle("settings.toggle.hideRestrictedChannels", isOn: $hideRestrictedChannels) 
            .help(Text("settings.toggle.hideRestrictedChannels.help"))
    }
}
//
//  PrivacyMode.swift
//  Stossycord
//
//  Created by Alex Badi on 11/10/2025.
//

import Foundation
import SwiftUI

enum PrivacyMode: String, CaseIterable, Identifiable {
    case standard
    case privacy
    case custom

    static let defaultMode: PrivacyMode = .standard

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .standard:
            return "Default"
        case .privacy:
            return "Privacy"
        case .custom:
            return "Custom"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .standard:
            return "All Discord content loads normally."
        case .privacy:
            return "Limits certain Discord calls. Only custom Stossycord emojis will load."
        case .custom:
            return "Fine-tune what Stossycord loads."
        }
    }

    var iconName: String {
        switch self {
        case .standard:
            return "network"
        case .privacy:
            return "lock.shield"
        case .custom:
            return "slider.horizontal.3"
        }
    }
}

//
//  MessageLayoutResolver.swift
//  Stossycord
//
//  Created by Alex Badi on 18/10/2025.
//

import SwiftUI

struct MessageLayoutResolver {
    let isCurrentUser: Bool
    let theme: MessageTheme

    var isTrailingAligned: Bool {
        switch theme.messageAlignment {
        case .standard:
            if isCurrentUser {
                return !theme.showSelfMessagesOnLeft
            } else {
                return false
            }
        case .allLeft:
            return false
        case .allRight:
            return true
        }
    }

    var usesCurrentUserStyle: Bool {
        guard isCurrentUser else { return false }
        if theme.useOtherStyleWhenSelfOnLeft && !isTrailingAligned {
            return false
        }
        return true
    }

    var columnAlignment: HorizontalAlignment {
        isTrailingAligned ? .trailing : .leading
    }

    var frameAlignment: Alignment {
        isTrailingAligned ? .trailing : .leading
    }

    var overlayAlignment: Alignment {
        Alignment(
            horizontal: isTrailingAligned ? .leading : .trailing,
            vertical: .center
        )
    }

    func activeSide(from configuration: MessageBubbleVisualConfiguration) -> MessageBubbleVisualConfiguration.Side {
        usesCurrentUserStyle ? configuration.currentUser : configuration.otherUser
    }
}

//
//  MessageTheme.swift
//  Stossycord
//
//  Created by Alex Badi on 16/10/2025.
//

import SwiftUI

struct MessageTheme: Equatable, Codable {
    var id: String
    var name: String
    var description: String?
    var iconName: String?
    var glassEffect: Bool
    var cornerRadius: CGFloat
    var strokeWidth: CGFloat
    var padding: PaddingInsets
    var groupedVerticalPadding: CGFloat
    var ungroupedVerticalPadding: CGFloat
    var horizontalPadding: CGFloat
    var currentUserSide: ThemeSide
    var otherUserSide: ThemeSide
    var avatarCornerRadius: CGFloat
    var avatarScale: CGFloat
    
    var showSelfMessagesOnLeft: Bool
    var showTimestamps: Bool
    var messageAlignment: MessageAlignment
    var useOtherStyleWhenSelfOnLeft: Bool
    
    var chatBackgroundColor: String?
    var chatBackgroundOpacity: CGFloat

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case iconName
        case glassEffect
        case cornerRadius
        case strokeWidth
        case padding
        case groupedVerticalPadding
        case ungroupedVerticalPadding
        case horizontalPadding
        case currentUserSide
        case otherUserSide
        case avatarCornerRadius
        case avatarScale
        case showSelfMessagesOnLeft
        case showTimestamps
        case messageAlignment
        case useOtherStyleWhenSelfOnLeft
        case chatBackgroundColor
        case chatBackgroundOpacity
    }
    
    enum MessageAlignment: String, Codable, CaseIterable {
        case standard
        case allLeft
        case allRight
        
        var displayName: String {
            switch self {
            case .standard: return "Standard"
            case .allLeft: return "All Left"
            case .allRight: return "All Right"
            }
        }
    }
    
    var chatBackgroundColorValue: Color? {
        guard let hex = chatBackgroundColor else { return nil }
        return Color(hex: hex)
    }
    
    struct PaddingInsets: Equatable, Codable {
        var top: CGFloat
        var leading: CGFloat
        var bottom: CGFloat
        var trailing: CGFloat
        
        var edgeInsets: EdgeInsets {
            EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        }
        
        static let standard = PaddingInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    }
    
    struct ThemeSide: Equatable, Codable {
        var background: String
        var text: String 
        var stroke: String?
        
        var backgroundColorValue: Color { Color(hex: background) ?? .blue }
        var textColorValue: Color { Color(hex: text) ?? .white }
        var strokeColorValue: Color? { 
            guard let stroke = stroke else { return nil }
            return Color(hex: stroke)
        }
    }

    init(
        id: String,
        name: String,
        description: String? = nil,
        iconName: String? = nil,
        glassEffect: Bool,
        cornerRadius: CGFloat,
        strokeWidth: CGFloat,
        padding: PaddingInsets,
        groupedVerticalPadding: CGFloat,
        ungroupedVerticalPadding: CGFloat,
        horizontalPadding: CGFloat,
        currentUserSide: ThemeSide,
        otherUserSide: ThemeSide,
        avatarCornerRadius: CGFloat,
        avatarScale: CGFloat,
        showSelfMessagesOnLeft: Bool,
        showTimestamps: Bool,
        messageAlignment: MessageAlignment,
        useOtherStyleWhenSelfOnLeft: Bool,
        chatBackgroundColor: String?,
        chatBackgroundOpacity: CGFloat
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.glassEffect = glassEffect
        self.cornerRadius = cornerRadius
        self.strokeWidth = strokeWidth
        self.padding = padding
        self.groupedVerticalPadding = groupedVerticalPadding
        self.ungroupedVerticalPadding = ungroupedVerticalPadding
        self.horizontalPadding = horizontalPadding
        self.currentUserSide = currentUserSide
        self.otherUserSide = otherUserSide
        self.avatarCornerRadius = avatarCornerRadius
        self.avatarScale = avatarScale
        self.showSelfMessagesOnLeft = showSelfMessagesOnLeft
        self.showTimestamps = showTimestamps
        self.messageAlignment = messageAlignment
        self.useOtherStyleWhenSelfOnLeft = useOtherStyleWhenSelfOnLeft
        self.chatBackgroundColor = chatBackgroundColor
        self.chatBackgroundOpacity = chatBackgroundOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        glassEffect = try container.decode(Bool.self, forKey: .glassEffect)
        cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
        strokeWidth = try container.decode(CGFloat.self, forKey: .strokeWidth)
        padding = try container.decode(PaddingInsets.self, forKey: .padding)
        groupedVerticalPadding = try container.decode(CGFloat.self, forKey: .groupedVerticalPadding)
        ungroupedVerticalPadding = try container.decode(CGFloat.self, forKey: .ungroupedVerticalPadding)
        horizontalPadding = try container.decode(CGFloat.self, forKey: .horizontalPadding)
        currentUserSide = try container.decode(ThemeSide.self, forKey: .currentUserSide)
        otherUserSide = try container.decode(ThemeSide.self, forKey: .otherUserSide)
        avatarCornerRadius = try container.decode(CGFloat.self, forKey: .avatarCornerRadius)
        avatarScale = try container.decodeIfPresent(CGFloat.self, forKey: .avatarScale) ?? 1.0
        showSelfMessagesOnLeft = try container.decode(Bool.self, forKey: .showSelfMessagesOnLeft)
        showTimestamps = try container.decode(Bool.self, forKey: .showTimestamps)
        messageAlignment = try container.decodeIfPresent(MessageAlignment.self, forKey: .messageAlignment) ?? .standard
        useOtherStyleWhenSelfOnLeft = try container.decodeIfPresent(Bool.self, forKey: .useOtherStyleWhenSelfOnLeft) ?? false
        chatBackgroundColor = try container.decodeIfPresent(String.self, forKey: .chatBackgroundColor)
        chatBackgroundOpacity = try container.decodeIfPresent(CGFloat.self, forKey: .chatBackgroundOpacity) ?? 1.0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(iconName, forKey: .iconName)
        try container.encode(glassEffect, forKey: .glassEffect)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(padding, forKey: .padding)
        try container.encode(groupedVerticalPadding, forKey: .groupedVerticalPadding)
        try container.encode(ungroupedVerticalPadding, forKey: .ungroupedVerticalPadding)
        try container.encode(horizontalPadding, forKey: .horizontalPadding)
        try container.encode(currentUserSide, forKey: .currentUserSide)
        try container.encode(otherUserSide, forKey: .otherUserSide)
        try container.encode(avatarCornerRadius, forKey: .avatarCornerRadius)
        try container.encode(avatarScale, forKey: .avatarScale)
        try container.encode(showSelfMessagesOnLeft, forKey: .showSelfMessagesOnLeft)
        try container.encode(showTimestamps, forKey: .showTimestamps)
        try container.encode(messageAlignment, forKey: .messageAlignment)
        try container.encode(useOtherStyleWhenSelfOnLeft, forKey: .useOtherStyleWhenSelfOnLeft)
        try container.encode(chatBackgroundColor, forKey: .chatBackgroundColor)
        try container.encode(chatBackgroundOpacity, forKey: .chatBackgroundOpacity)
    }
    
    // MARK: - Built-in Themes
    
    static let imessage = MessageTheme(
        id: "imessage",
        name: "iMessage",
        description: "Rounded blue bubbles inspired by iMessage.",
        iconName: "message.fill",
        glassEffect: true,
        cornerRadius: 18,
        strokeWidth: 0,
        padding: .standard,
        groupedVerticalPadding: 0,
        ungroupedVerticalPadding: 6,
        horizontalPadding: 6,
        currentUserSide: ThemeSide(
            background: "#1A7FFF",
            text: "#FFFFFF",
            stroke: nil
        ),
        otherUserSide: ThemeSide(
            background: "#8E8E93",
            text: "#FFFFFF",
            stroke: nil
        ),
        avatarCornerRadius: 50,
        avatarScale: 1.0,
        showSelfMessagesOnLeft: false,
        showTimestamps: false,
        messageAlignment: .standard,
        useOtherStyleWhenSelfOnLeft: false,
        chatBackgroundColor: nil,
        chatBackgroundOpacity: 1.0
    )
    
    static let discord = MessageTheme(
        id: "discord",
        name: "Discord",
        description: "Dark theme similar to Discord.",
        iconName: "bubble.left.and.bubble.right.fill",
        glassEffect: false,
        cornerRadius: 8,
        strokeWidth: 0,
        padding: PaddingInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
        groupedVerticalPadding: 0,
        ungroupedVerticalPadding: 4,
        horizontalPadding: 4,
        currentUserSide: ThemeSide(
            background: "#5865F2",
            text: "#FFFFFF",
            stroke: nil
        ),
        otherUserSide: ThemeSide(
            background: "#2B2D31",
            text: "#DBDEE1",
            stroke: nil
        ),
        avatarCornerRadius: 50,
        avatarScale: 0.7,
        showSelfMessagesOnLeft: true,
        showTimestamps: false,
        messageAlignment: .allLeft,
        useOtherStyleWhenSelfOnLeft: false,
        chatBackgroundColor: "#313338",
        chatBackgroundOpacity: 1.0
    )
    
    static let minimal = MessageTheme(
        id: "minimal",
        name: "Minimal",
        description: "Clean, balanced bubbles with light surfaces and soft borders.",
        iconName: "text.alignleft",
        glassEffect: false,
        cornerRadius: 12,
        strokeWidth: 1,
        padding: PaddingInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
        groupedVerticalPadding: 2,
        ungroupedVerticalPadding: 6,
        horizontalPadding: 4,
        currentUserSide: ThemeSide(
            background: "#007AFF",
            text: "#FFFFFF",
            stroke: "#4DA3FF"
        ),
        otherUserSide: ThemeSide(
            background: "#F2F2F7",
            text: "#000000",
            stroke: "#D1D1D6"
        ),
        avatarCornerRadius: 4,
        avatarScale: 1.0,
        showSelfMessagesOnLeft: false,
        showTimestamps: true,
        messageAlignment: .standard,
        useOtherStyleWhenSelfOnLeft: false,
        chatBackgroundColor: nil,
        chatBackgroundOpacity: 1.0
    )
    
    static let bubbles = MessageTheme(
        id: "bubbles",
        name: "Bubbles",
        description: "Playful dual-tone bubbles with a luminous glass effect.",
        iconName: "bubble.left.fill",
        glassEffect: true,
        cornerRadius: 20,
        strokeWidth: 0,
        padding: PaddingInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
        groupedVerticalPadding: 1,
        ungroupedVerticalPadding: 8,
        horizontalPadding: 8,
        currentUserSide: ThemeSide(
            background: "#34C759",
            text: "#FFFFFF",
            stroke: nil
        ),
        otherUserSide: ThemeSide(
            background: "#FF9500",
            text: "#FFFFFF",
            stroke: nil
        ),
        avatarCornerRadius: 18,
        avatarScale: 1.0,
        showSelfMessagesOnLeft: false,
        showTimestamps: true,
        messageAlignment: .standard,
        useOtherStyleWhenSelfOnLeft: false,
        chatBackgroundColor: nil,
        chatBackgroundOpacity: 0.95
    )
    
    static let modern = MessageTheme(
        id: "modern",
        name: "Modern",
        description: "Polished glass treatment with neutral tones and defined strokes.",
        iconName: "rectangle.stack.fill",
        glassEffect: true,
        cornerRadius: 16,
        strokeWidth: 1.5,
        padding: .standard,
        groupedVerticalPadding: 2,
        ungroupedVerticalPadding: 8,
        horizontalPadding: 6,
        currentUserSide: ThemeSide(
            background: "#0A84FF",
            text: "#FFFFFF",
            stroke: "#64B5F6"
        ),
        otherUserSide: ThemeSide(
            background: "#E5E5EA",
            text: "#000000",
            stroke: "#C7C7CC"
        ),
        avatarCornerRadius: 8,
        avatarScale: 1.0,
        showSelfMessagesOnLeft: false,
        showTimestamps: true,
        messageAlignment: .standard,
        useOtherStyleWhenSelfOnLeft: false,
        chatBackgroundColor: nil,
        chatBackgroundOpacity: 1.0
    )
    
    static let builtInThemes: [MessageTheme] = [
        .imessage,
        .discord,
        .minimal,
        .bubbles,
        .modern
    ]
    
    // MARK: - JSON Conversion
    
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    static func fromJSON(_ json: String) -> MessageTheme? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(MessageTheme.self, from: data)
        } catch {
            print("Failed to decode theme JSON: \(error)")
            return nil
        }
    }
    
    static func isValidJSON(_ json: String) -> Bool {
        fromJSON(json) != nil
    }
    
    // MARK: - Compatibility with MessageBubbleVisualConfiguration
    
    func toVisualConfiguration() -> MessageBubbleVisualConfiguration {
        MessageBubbleVisualConfiguration(theme: self)
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "imessage"
    @AppStorage("customThemeJSON") private var customThemeJSON: String = ""
    @AppStorage("customThemes") private var customThemesJSON: String = "[]"
    
    @Published var selectedTheme: MessageTheme
    @Published var customThemes: [MessageTheme]
    
    init() {
        self.selectedTheme = .imessage
        self.customThemes = []

        let loadedCustomThemes: [MessageTheme]
        let storedCustomThemesJSON = customThemesJSON
        if let data = storedCustomThemesJSON.data(using: .utf8),
           let themes = try? JSONDecoder().decode([MessageTheme].self, from: data) {
            loadedCustomThemes = themes
        } else {
            loadedCustomThemes = []
        }
        
        self.customThemes = loadedCustomThemes
        
        let storedSelectedThemeID = selectedThemeID
        if let customTheme = loadedCustomThemes.first(where: { $0.id == storedSelectedThemeID }) {
            self.selectedTheme = customTheme
        } else if let builtIn = MessageTheme.builtInThemes.first(where: { $0.id == storedSelectedThemeID }) {
            self.selectedTheme = builtIn
        } else {
            self.selectedTheme = .imessage
        }
    }
    
    var allThemes: [MessageTheme] {
        MessageTheme.builtInThemes + customThemes
    }
    
    func selectTheme(_ theme: MessageTheme) {
        selectedTheme = theme
        selectedThemeID = theme.id
    }
    
    func addCustomTheme(_ theme: MessageTheme) {
        customThemes.append(theme)
        saveCustomThemes()
    }
    
    func updateCustomTheme(_ theme: MessageTheme) {
        if let index = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[index] = theme
            saveCustomThemes()
            if selectedThemeID == theme.id {
                selectedTheme = theme
            }
        }
    }
    
    func deleteCustomTheme(_ theme: MessageTheme) {
        customThemes.removeAll { $0.id == theme.id }
        saveCustomThemes()
        if selectedThemeID == theme.id {
            selectTheme(.imessage)
        }
    }
    
    func duplicateTheme(_ theme: MessageTheme, newName: String) -> MessageTheme {
        var newTheme = theme
        newTheme.id = "custom_\(UUID().uuidString)"
        newTheme.name = newName
        return newTheme
    }
    
    func isBuiltInTheme(_ theme: MessageTheme) -> Bool {
        MessageTheme.builtInThemes.contains(where: { $0.id == theme.id })
    }
    
    private func saveCustomThemes() {
        if let data = try? JSONEncoder().encode(customThemes),
           let string = String(data: data, encoding: .utf8) {
            customThemesJSON = string
        }
    }
}

// MARK: - Theme Settings Keys

enum ThemeSettingsKeys {
    static let selectedThemeID = "selectedThemeID"
    static let customThemeJSON = "customThemeJSON"
    static let customThemes = "customThemes"
}

// MARK: - Update MessageBubbleVisualConfiguration to support themes

extension MessageBubbleVisualConfiguration {
    init(theme: MessageTheme) {
        self.glassEffect = theme.glassEffect
        self.cornerRadius = theme.cornerRadius
        self.strokeWidth = theme.strokeWidth
        self.padding = PaddingSet(
            top: theme.padding.top,
            leading: theme.padding.leading,
            bottom: theme.padding.bottom,
            trailing: theme.padding.trailing
        )
        self.groupedVerticalPadding = theme.groupedVerticalPadding
        self.ungroupedVerticalPadding = theme.ungroupedVerticalPadding
        self.horizontalPadding = theme.horizontalPadding
        self.currentUser = Side(
            background: theme.currentUserSide.backgroundColorValue,
            text: theme.currentUserSide.textColorValue,
            stroke: theme.currentUserSide.strokeColorValue
        )
        self.otherUser = Side(
            background: theme.otherUserSide.backgroundColorValue,
            text: theme.otherUserSide.textColorValue,
            stroke: theme.otherUserSide.strokeColorValue
        )
        self.avatarCornerRadius = theme.avatarCornerRadius
        self.avatarScale = theme.avatarScale
    }
}

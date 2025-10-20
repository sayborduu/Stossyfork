//
//  Themes.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/25.
//

import SwiftUI

struct ThemeSettings: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var isPresentingThemeEditor = false
    @State private var themeEditorExistingTheme: MessageTheme?
    @State private var themeEditorBaseTheme: MessageTheme?
    @State private var showingThemeTemplatePicker = false
    @State private var themePendingDeletion: MessageTheme?

    var body: some View {
        List {
            Section(
                header: Text("Active Theme")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary),
                footer: Text("Select a theme or create your own. Your choice will be saved.")
                    .font(.footnote)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(themeManager.selectedTheme.name)
                        .font(.headline)
                    if let description = themeManager.selectedTheme.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)

                ThemePreviewView(theme: themeManager.selectedTheme, websocketService: WebSocketService.shared)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground({
                        if let bgColor = themeManager.selectedTheme.chatBackgroundColor, !bgColor.isEmpty {
                            Color(hex: bgColor)
                        } else {
                            Color.clear
                        }
                    }())
                    .animation(.easeInOut(duration: 0.3), value: themeManager.selectedTheme.chatBackgroundColor)
                    .listRowSeparator(.hidden)

                Button {
                    showingThemeTemplatePicker = true
                } label: {
                    Label("Create Custom Theme", systemImage: "plus")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.top, 8)
            }

            Section(
                header: Text("Built-in Themes")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            ) {
                ForEach(MessageTheme.builtInThemes, id: \.id) { theme in
                    themeRow(for: theme, isCustom: false)
                }
            }

            Section(
                header: Text("Custom Themes")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary),
                footer: customThemesFooter
            ) {
                if themeManager.customThemes.isEmpty {
                    Text("You haven't created any custom themes yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(themeManager.customThemes, id: \.id) { theme in
                        themeRow(for: theme, isCustom: true)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(SettingsDestination.themes.titleKey)
        .sheet(isPresented: $showingThemeTemplatePicker) {
            NavigationStack {
                ThemeTemplatePickerView(themeManager: themeManager, websocketService: WebSocketService.shared)
            }
        }
        .fullScreenCover(isPresented: $isPresentingThemeEditor) {
            NavigationStack {
                CustomThemeEditorView(
                    themeManager: themeManager,
                    existingTheme: themeEditorExistingTheme,
                    baseTheme: themeEditorBaseTheme,
                    websocketService: WebSocketService.shared
                )
            }
            .onDisappear {
                themeEditorExistingTheme = nil
                themeEditorBaseTheme = nil
            }
        }
        .confirmationDialog(
            "Delete theme?",
            isPresented: Binding(
                get: { themePendingDeletion != nil },
                set: { newValue in
                    if !newValue {
                        themePendingDeletion = nil
                    }
                }
            ),
            presenting: themePendingDeletion
        ) { theme in
            Button("Delete \(theme.name)", role: .destructive) {
                themeManager.deleteCustomTheme(theme)
                themePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                themePendingDeletion = nil
            }
        } message: { theme in
            Text("This will remove the custom theme \(theme.name). This action cannot be undone.")
        }
    }

    private var customThemesFooter: some View {
        Text("Swipe or long-press a theme to edit, duplicate, or delete it.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func themeRow(for theme: MessageTheme, isCustom: Bool) -> some View {
        let isSelected = themeManager.selectedTheme.id == theme.id

        Button {
            themeManager.selectTheme(theme)
        } label: {
            HStack(spacing: 12) {
                ThemeListLabel(theme: theme, iconColor: isSelected ? .accentColor : .secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            themeContextMenu(for: theme, isCustom: isCustom)
        }
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isCustom {
                Button {
                    beginEditing(theme)
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.3")
                }
                .tint(.blue)

                Button {
                    duplicateTheme(theme)
                } label: {
                    Label("Duplicate", systemImage: "square.on.square")
                }
                .tint(.orange)

                Button(role: .destructive) {
                    requestDelete(theme)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button {
                    duplicateTheme(theme)
                } label: {
                    Label("Duplicate", systemImage: "square.on.square")
                }
                .tint(.orange)
            }
        }
        #endif
    }

    @ViewBuilder
    private func themeContextMenu(for theme: MessageTheme, isCustom: Bool) -> some View {
        Button {
            duplicateTheme(theme)
        } label: {
            Label("Duplicate", systemImage: "square.on.square")
        }

        if isCustom {
            Button {
                beginEditing(theme)
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }

            Button(role: .destructive) {
                requestDelete(theme)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func beginEditing(_ theme: MessageTheme) {
        themeEditorExistingTheme = theme
        themeEditorBaseTheme = nil
        DispatchQueue.main.async {
            isPresentingThemeEditor = true
        }
    }

    private func duplicateTheme(_ theme: MessageTheme) {
        themeEditorExistingTheme = nil
        themeEditorBaseTheme = theme
        DispatchQueue.main.async {
            isPresentingThemeEditor = true
        }
    }

    private func requestDelete(_ theme: MessageTheme) {
        themePendingDeletion = theme
    }
}
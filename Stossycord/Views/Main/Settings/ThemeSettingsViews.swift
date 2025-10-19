//
//  ThemeSettingsViews.swift
//  Stossycord
//
//  Created by Alex Badi on 18/10/2025.
//

import SwiftUI
import SFSymbolsPicker

struct ThemeListLabel: View {
    let theme: MessageTheme
    var iconColor: Color = .accentColor
    private let fallbackIconName = "paintbrush.fill"

    private var effectiveIconName: String {
        let trimmed = theme.iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallbackIconName : trimmed
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: effectiveIconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name)
                    .foregroundColor(.primary)
                if let description = theme.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ThemeTemplatePickerView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var websocketService: WebSocketService

    var body: some View {
        List {
            Section(
                header: Text("Start from Blank")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary),
                footer: Text("Create a completely new theme from scratch with default settings.")
                    .font(.footnote)
            ) {
                NavigationLink {
                    CustomThemeEditorView(themeManager: themeManager, baseTheme: nil, websocketService: websocketService)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Blank Theme")
                                .foregroundColor(.primary)
                            Text("Start fresh with default values and customise everything.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section(
                header: Text("Based on Built-in Theme")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary),
                footer: Text("Start with a built-in theme as a template and customise it to your liking.")
                    .font(.footnote)
            ) {
                ForEach(MessageTheme.builtInThemes, id: \.id) { theme in
                    NavigationLink {
                        CustomThemeEditorView(themeManager: themeManager, baseTheme: theme, websocketService: websocketService)
                    } label: {
                        ThemeListLabel(theme: theme)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Choose Template")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CustomThemeEditorView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var websocketService: WebSocketService
    @Environment(\.dismiss) private var dismiss

    let existingTheme: MessageTheme?
    let isEditing: Bool
    private let baselineTheme: MessageTheme

    @State private var editedTheme: MessageTheme
    @State private var showJSONEditor: Bool = false
    @State private var themeJSON: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showDiscardAlert = false
    @State private var isSheetPresented = false
    @State private var icon: String = "paintbrush.fill"
    @State private var iconSize: CGFloat = 25

    init(themeManager: ThemeManager, existingTheme: MessageTheme? = nil, baseTheme: MessageTheme? = nil, websocketService: WebSocketService) {
        self.themeManager = themeManager
        self.websocketService = websocketService
        self.existingTheme = existingTheme
        self.isEditing = existingTheme != nil

        let initialTheme: MessageTheme
        if let existing = existingTheme {
            initialTheme = existing
        } else if let base = baseTheme {
            var newTheme = base
            newTheme.id = "custom_\(UUID().uuidString)"
            newTheme.name = "\(base.name) (Custom)"
            self.icon = newTheme.iconName ?? "paintbrush.fill"
            initialTheme = newTheme
        } else {
            var blankTheme = MessageTheme.imessage
            blankTheme.id = "custom_\(UUID().uuidString)"
            blankTheme.name = "My Custom Theme"
            blankTheme.description = nil
            blankTheme.iconName = nil
            self.icon = blankTheme.iconName ?? "paintbrush.fill"
            initialTheme = blankTheme
        }
        _editedTheme = State(initialValue: initialTheme)
        self.baselineTheme = initialTheme
    }

    init(themeManager: ThemeManager, existingTheme: MessageTheme?) {
        self.init(themeManager: themeManager, existingTheme: existingTheme, baseTheme: nil, websocketService: WebSocketService.shared)
    }

    var body: some View {
        List {
            Section {
                Picker("Edit Mode", selection: $showJSONEditor) {
                    Text("Visual").tag(false)
                    Text("JSON").tag(true)
                }
                .pickerStyle(.segmented)
            }

            Section(
                header: Text("Live Preview")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            ) {
                ThemePreviewView(theme: previewTheme, websocketService: websocketService)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if showJSONEditor {
                jsonEditorSection
            } else {
                visualEditorSections
            }

            Section {
                Button(isEditing ? "Save Changes" : "Create Theme") {
                    saveTheme()
                }
                .disabled(editedTheme.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isEditing ? "Edit Theme" : "Create Theme")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: attemptDismiss) {
                    Label("Back", systemImage: "chevron.left")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(action: saveTheme) {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .alert("Discard changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You haven't saved your changes.")
        }
        .onAppear {
            if let json = editedTheme.toJSON() {
                themeJSON = json
            }
        }
        .sheet(isPresented: $isSheetPresented) {
            SymbolsPicker(
                selection: $icon,
                title: "Choose your icon",
                autoDismiss: true
            ) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.accentColor)
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        editedTheme != baselineTheme
    }

    private var previewTheme: MessageTheme {
        var theme = editedTheme
        theme.name = baselineTheme.name
        theme.description = baselineTheme.description
        theme.iconName = baselineTheme.iconName
        return theme
    }

    private func attemptDismiss() {
        if hasUnsavedChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var visualEditorSections: some View {
        basicInfoSection
        layoutSection
        bubbleStyleSection
        colorSections
        spacingSection
        avatarSection
        backgroundSection
    }

    private var basicInfoSection: some View {
        Section(header: Text("Metadata")) {
            TextField("Theme Name", text: $editedTheme.name)

            TextField(
                "Description (optional)",
                text: Binding(
                    get: { editedTheme.description ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        editedTheme.description = trimmed.isEmpty ? nil : trimmed
                    }
                )
            )

            Button(action: { isSheetPresented = true }) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(.accentColor)
                    .frame(width: iconSize*1.5, height: iconSize*1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .disabled(isSheetPresented)
        }
    }

    private var layoutSection: some View {
        Section(header: Text("Layout")) {
            Picker("Message alignment", selection: $editedTheme.messageAlignment) {
                ForEach(MessageTheme.MessageAlignment.allCases, id: \.self) { alignment in
                    Text(alignment.displayName).tag(alignment)
                }
            }

            Toggle("Show Self messages on left", isOn: $editedTheme.showSelfMessagesOnLeft)
            Toggle("Show timestamps", isOn: $editedTheme.showTimestamps)
            if editedTheme.showSelfMessagesOnLeft || editedTheme.messageAlignment == .allLeft {
                Toggle("Match others style when self messages are left", isOn: $editedTheme.useOtherStyleWhenSelfOnLeft)
                    .tint(.blue)
                    .transition(.opacity)
            }
        }
    }

    private var bubbleStyleSection: some View {
        Section(header: Text("Bubble Style")) {
            Toggle("Glass Effect", isOn: $editedTheme.glassEffect)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Text("\(Int(editedTheme.cornerRadius))px")
                        .foregroundColor(.secondary)
                }
                Slider(value: $editedTheme.cornerRadius, in: 0...30, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stroke Width")
                    Spacer()
                    Text("\(Int(editedTheme.strokeWidth))px")
                        .foregroundColor(.secondary)
                }
                Slider(value: $editedTheme.strokeWidth, in: 0...5, step: 0.5)
            }
        }
    }

    @ViewBuilder
    private var colorSections: some View {
        Section(header: Text("Your Messages")) {
            ThemeColorEditorView(side: $editedTheme.currentUserSide)
        }

        Section(header: Text("Other Messages")) {
            ThemeColorEditorView(side: $editedTheme.otherUserSide)
        }
    }

    private var spacingSection: some View {
        Section(header: Text("Spacing")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Horizontal Padding")
                    Spacer()
                    Text("\(Int(editedTheme.horizontalPadding))px")
                        .foregroundColor(.secondary)
                }
                Slider(value: $editedTheme.horizontalPadding, in: 0...20, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ungrouped Vertical Padding")
                    Spacer()
                    Text("\(Int(editedTheme.ungroupedVerticalPadding))px")
                        .foregroundColor(.secondary)
                }
                Slider(value: $editedTheme.ungroupedVerticalPadding, in: 0...20, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Grouped Vertical Padding")
                    Spacer()
                    Text("\(Int(editedTheme.groupedVerticalPadding))px")
                        .foregroundColor(.secondary)
                }
                Slider(value: $editedTheme.groupedVerticalPadding, in: 0...10, step: 1)
            }

            ThemePaddingEditorView(padding: $editedTheme.padding)
        }
    }

    private var avatarSection: some View {
        Section(header: Text("Avatar")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Avatar Corner Radius")
                    Spacer()
                    Text("\(Int(editedTheme.avatarCornerRadius))px")
                        .foregroundColor(.secondary)
                }
                Slider(value: $editedTheme.avatarCornerRadius, in: 0...50, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Avatar Scale")
                    Spacer()
                    Text(String(format: "%.1fx", editedTheme.avatarScale))
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(editedTheme.avatarScale) },
                        set: { editedTheme.avatarScale = CGFloat($0) }
                    ),
                    in: 0.5...1.5,
                    step: 0.05
                )
            }
        }
    }

    private var backgroundSection: some View {
        Section(header: Text("Chat Background")) {
                ThemeBackgroundColorEditorView(
                    backgroundColor: Binding(
                        get: { editedTheme.chatBackgroundColor },
                        set: { editedTheme.chatBackgroundColor = $0 }
                    ),
                    opacity: $editedTheme.chatBackgroundOpacity
                )
        }
    }

    private var jsonEditorSection: some View {
        Section(header: Text("JSON Editor")) {
            TextEditor(text: $themeJSON)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 400)
                .padding(8)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                #endif

            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Load from JSON") {
                loadFromJSON()
            }
        }
    }

    private func loadFromJSON() {
        guard let theme = MessageTheme.fromJSON(themeJSON) else {
            showError = true
            errorMessage = "Invalid JSON. Please check your theme configuration."
            return
        }
        editedTheme = theme
        showError = false
    }

    private func saveTheme() {
        if showJSONEditor {
            loadFromJSON()
            guard !showError else { return }
        }

        var themeToSave = editedTheme

        if isEditing {
            if !themeManager.isBuiltInTheme(existingTheme ?? editedTheme) {
                themeManager.updateCustomTheme(themeToSave)
                themeManager.selectTheme(themeToSave)
            }
        } else {
            if themeToSave.id.isEmpty || themeManager.isBuiltInTheme(themeToSave) {
                themeToSave.id = "custom_\(UUID().uuidString)"
            }
            themeManager.addCustomTheme(themeToSave)
            themeManager.selectTheme(themeToSave)
        }

        dismiss()
    }
}

struct ThemeColorEditorView: View {
    @Binding var side: MessageTheme.ThemeSide

    @State private var backgroundColor: String
    @State private var textColor: String
    @State private var strokeColor: String
    @State private var useStroke: Bool

    init(side: Binding<MessageTheme.ThemeSide>) {
        self._side = side
        _backgroundColor = State(initialValue: side.wrappedValue.background)
        _textColor = State(initialValue: side.wrappedValue.text)
        _strokeColor = State(initialValue: side.wrappedValue.stroke ?? "#000000")
        _useStroke = State(initialValue: side.wrappedValue.stroke != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorPickerRow(title: "Background", hexColor: $backgroundColor)
            ColorPickerRow(title: "Text", hexColor: $textColor)

            Toggle("Enable Stroke", isOn: $useStroke)

            if useStroke {
                ColorPickerRow(title: "Stroke", hexColor: $strokeColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: backgroundColor) { _ in updateSide() }
        .onChange(of: textColor) { _ in updateSide() }
        .onChange(of: strokeColor) { _ in updateSide() }
        .onChange(of: useStroke) { _ in updateSide() }
        .onChange(of: side) { newValue in
            backgroundColor = newValue.background
            textColor = newValue.text
            strokeColor = newValue.stroke ?? strokeColor
            useStroke = newValue.stroke != nil
        }
        .animation(.default, value: useStroke)
    }

    private func updateSide() {
        side.background = backgroundColor
        side.text = textColor
        side.stroke = useStroke ? strokeColor : nil
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var hexColor: String

    @State private var tempColor: Color

    init(title: String, hexColor: Binding<String>) {
        self.title = title
        self._hexColor = hexColor
        let initial = Color(hex: hexColor.wrappedValue) ?? .white
        _tempColor = State(initialValue: initial)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            ColorPicker("", selection: $tempColor, supportsOpacity: true)
                .labelsHidden()
                .frame(maxWidth: 160)
        }
        .padding(.vertical, 4)
        .onChange(of: tempColor) { newColor in
            guard let hex = newColor.toHex(includeAlpha: true) else { return }
            if hex.count == 9,
               let colorObj = Color(hex: hex),
               let uiHex = colorObj.toHex(includeAlpha: false) {
                hexColor = uiHex
            } else {
                hexColor = hex
            }
        }
        .onChange(of: hexColor) { newValue in
            guard let updated = Color(hex: newValue) else { return }
            tempColor = updated
        }
    }
}

struct ThemePaddingEditorView: View {
    @Binding var padding: MessageTheme.PaddingInsets

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            paddingSlider(title: "Top", value: $padding.top)
            paddingSlider(title: "Leading", value: $padding.leading)
            paddingSlider(title: "Bottom", value: $padding.bottom)
            paddingSlider(title: "Trailing", value: $padding.trailing)
        }
    }

    private func paddingSlider(title: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))px")
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: 0...30, step: 1)
        }
    }
}

struct ThemeBackgroundColorEditorView: View {
    @Binding var backgroundColor: String?
    @Binding var opacity: CGFloat

    @State private var useCustomBackground: Bool
    @State private var colorHex: String

    init(backgroundColor: Binding<String?>, opacity: Binding<CGFloat>) {
        self._backgroundColor = backgroundColor
        self._opacity = opacity
        _useCustomBackground = State(initialValue: backgroundColor.wrappedValue != nil)
        _colorHex = State(initialValue: backgroundColor.wrappedValue ?? "#FFFFFF")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use Custom Background", isOn: $useCustomBackground)

            if useCustomBackground {
                ColorPickerRow(title: "Background", hexColor: $colorHex)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Text("\(Int(opacity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $opacity, in: 0...1, step: 0.05)
                }
            }
        }
        .onChange(of: useCustomBackground) { newValue in
            backgroundColor = newValue ? colorHex : nil
        }
        .onChange(of: colorHex) { newValue in
            if useCustomBackground {
                backgroundColor = newValue
            }
        }
        .onChange(of: backgroundColor) { newValue in
            useCustomBackground = newValue != nil
            colorHex = newValue ?? colorHex
        }
    }
}

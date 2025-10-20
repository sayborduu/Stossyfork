//
//  General.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/25.
//  Created by Alex Badi on 19/10/2025.

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct GeneralSettings: View {
    @AppStorage("useSettingsTabLabel") private var useSettingsTabLabel: Bool = true

    @State private var appIconOptions: [AppIconDescriptor] = AppIconManager.availableIcons()
    @State private var selectedAppIconName: String? = AppIconManager.currentIconName()
    @State private var isSettingAppIcon = false
    @State private var appIconErrorMessage: String?
    @State private var groupedBackgroundColor: Color

    init(groupedBackgroundColor: Color) {
        _groupedBackgroundColor = State(initialValue: groupedBackgroundColor)
    }
    
    var body: some View {
        Toggle("settings.toggle.useSettingsTabLabel", isOn: $useSettingsTabLabel)
            .help(Text("settings.toggle.useSettingsTabLabel.help"))

        VStack(alignment: .leading, spacing: 12) {
            Text("App Icon")
                .font(.headline)

            if appIconOptions.isEmpty {
                Text("No alternate icons are configured yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appIconOptions) { option in
                    Button {
                        selectAppIcon(option)
                    } label: {
                        HStack(spacing: 12) {
                            platformImage(for: option)
                                .resizable()
                                .renderingMode(.original)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.displayName)
                                    .font(.subheadline.weight(.semibold))
                                if !option.description.isEmpty {
                                    Text(option.description)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if isAppIconSelected(option) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isAppIconSelected(option) ? Color.accentColor.opacity(0.12) : groupedBackgroundColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSettingAppIcon || !AppIconManager.supportsAlternateIcons)
                }
            }

            if !AppIconManager.supportsAlternateIcons {
                Text("Alternate icons are not available on this platform.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = appIconErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if isSettingAppIcon {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .help(Text("Select the app icon to use."))
        .onAppear(perform: refreshAppIconOptions)
    }

    func refreshAppIconOptions() {
        appIconOptions = AppIconManager.availableIcons()
        selectedAppIconName = AppIconManager.currentIconName()
    }

    func isAppIconSelected(_ option: AppIconDescriptor) -> Bool {
        if option.iconName == nil {
            return selectedAppIconName == nil
        }
        return option.iconName == selectedAppIconName
    }

    func selectAppIcon(_ option: AppIconDescriptor) {
        guard AppIconManager.supportsAlternateIcons else {
            return
        }
        if isAppIconSelected(option) {
            return
        }
        isSettingAppIcon = true
        appIconErrorMessage = nil
        AppIconManager.setIcon(named: option.iconName) { error in
            if let error = error {
                appIconErrorMessage = error.localizedDescription
                isSettingAppIcon = false
                return
            }
            selectedAppIconName = option.iconName
            refreshAppIconOptions()
            isSettingAppIcon = false
        }
    }
}

extension GeneralSettings {
    struct ImageBuilder {
        static func image(for descriptor: AppIconDescriptor) -> Image? {
            for candidate in descriptor.imageCandidateNames {
                if let uiImage = UIImage(named: candidate) {
                    return Image(uiImage: uiImage)
                }
            }
            return nil
        }
    }
    
    func platformImage(for descriptor: AppIconDescriptor) -> Image {
        #if os(macOS)
        for candidate in descriptor.imageCandidateNames {
            if let nsImage = NSImage(named: candidate) {
                return Image(nsImage: nsImage)
            }
        }
        return Image(systemName: "photo")
        #else
        if let image = ImageBuilder.image(for: descriptor) {
            return image
        }
        return Image(systemName: "photo")
        #endif
    }
}
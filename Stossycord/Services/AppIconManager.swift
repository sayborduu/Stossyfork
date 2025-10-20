//
//  AppIconManager.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/2025.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct AppIconDescriptor: Identifiable, Hashable {
    let id: String
    let iconName: String?
    let assetName: String
    let displayName: String
    let description: String
    let additionalImageNames: [String]
}

enum AppIconManager {
    private struct IconMetadata {
        let title: String
        let description: String
        let additionalImageNames: [String]
    }

    private static let iconMetadata: [String: IconMetadata] = [
        "AppIcon": IconMetadata(
            title: "Default",
            description: "Default stossycord green.",
            additionalImageNames: [
                "AppIcon",
                "StossycordLogo (2)",
                "StossycordLogoDark",
                "StossycordLogoTinted"
            ]
        ),
        "AppIconLGBT": IconMetadata(
            title: "LGBTQIA+",
            description: "Rainbow vibes in your chats!",
            additionalImageNames: [
                "AppIconLGBT",
                "AppIconLGBT-iOS-Default-1024x1024@1x",
                "AppIconLGBT-iOS-Dark-1024x1024@1x",
                "Frame 1"
            ]
        )
    ]

    static func availableIcons() -> [AppIconDescriptor] {
        var options: [AppIconDescriptor] = []
        let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primaryIdentifier = primaryIconIdentifier(from: iconsDictionary)
        let primaryAssetName = iconAssetName(from: iconsDictionary?["CFBundlePrimaryIcon"], fallback: primaryIdentifier)
        let primaryMetadata = metadata(for: primaryIdentifier)

        options.append(
            AppIconDescriptor(
                id: primaryIdentifier,
                iconName: nil,
                assetName: primaryAssetName,
                displayName: primaryMetadata.title,
                description: primaryMetadata.description,
                additionalImageNames: primaryMetadata.additionalImageNames
            )
        )

        if let alternates = iconsDictionary?["CFBundleAlternateIcons"] as? [String: Any] {
            let sortedAlternates = alternates.sorted { $0.key < $1.key }
            for (key, value) in sortedAlternates {
                let assetName = iconAssetName(from: value, fallback: key)
                let metadata = metadata(for: key)
                options.append(
                    AppIconDescriptor(
                        id: key,
                        iconName: key,
                        assetName: assetName,
                        displayName: metadata.title,
                        description: metadata.description,
                        additionalImageNames: metadata.additionalImageNames
                    )
                )
            }
        }

        return options
    }

    static func descriptor(for iconName: String?) -> AppIconDescriptor? {
        let icons = availableIcons()
        if let iconName {
            return icons.first { $0.iconName == iconName }
        }
        return icons.first { $0.iconName == nil } ?? icons.first
    }

    static func currentIconName() -> String? {
        #if canImport(UIKit) && !os(macOS)
        return UIApplication.shared.alternateIconName
        #else
        return nil
        #endif
    }

    static var supportsAlternateIcons: Bool {
        #if canImport(UIKit) && !os(macOS)
        return UIApplication.shared.supportsAlternateIcons
        #else
        return false
        #endif
    }

    static func setIcon(named iconName: String?, completion: @escaping (Error?) -> Void) {
        #if canImport(UIKit) && !os(macOS)
        guard UIApplication.shared.supportsAlternateIcons else {
            DispatchQueue.main.async {
                completion(NSError(domain: "AppIconManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Alternate icons are not supported on this device."]))
            }
            return
        }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
        #else
        DispatchQueue.main.async {
            completion(NSError(domain: "AppIconManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Alternate icons are only available on iOS."]))
        }
        #endif
    }

    private static func primaryIconIdentifier(from iconsDictionary: [String: Any]?) -> String {
        if let primaryIcon = iconsDictionary?["CFBundlePrimaryIcon"] as? [String: Any],
           let iconName = primaryIcon["CFBundleIconName"] as? String {
            return iconName
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String {
            return name
        }
        return "AppIcon"
    }

    private static func metadata(for iconKey: String) -> IconMetadata {
        if let metadata = iconMetadata[iconKey] {
            return metadata
        }
        let formattedTitle = iconKey.replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return IconMetadata(
            title: formattedTitle.isEmpty ? "App Icon" : formattedTitle,
            description: "",
            additionalImageNames: [iconKey]
        )
    }

    private static func iconAssetName(from value: Any?, fallback: String) -> String {
        if let dictionary = value as? [String: Any] {
            if let iconFiles = dictionary["CFBundleIconFiles"] as? [String], let last = iconFiles.last {
                return last
            }
            if let iconName = dictionary["CFBundleIconName"] as? String {
                return iconName
            }
        }
        return fallback
    }
}

extension AppIconDescriptor {
    var imageCandidateNames: [String] {
        var candidates: [String] = []
        var seen = Set<String>()

        func append(_ name: String) {
            guard !name.isEmpty else { return }
            if seen.insert(name).inserted {
                candidates.append(name)
            }
        }

        func stripScaleSuffix(from name: String) -> String {
            guard let atIndex = name.lastIndex(of: "@") else { return name }
            let suffix = String(name[atIndex...]).lowercased()
            let digits = suffix.dropFirst().dropLast()
            if suffix.hasPrefix("@"), suffix.hasSuffix("x"), digits.allSatisfy({ $0.isNumber }) {
                return String(name[..<atIndex])
            }
            return name
        }

        func sanitizedVariants(for name: String) -> [String] {
            var results: [String] = []
            var seenVariants = Set<String>()
            let transformations: [(String) -> String] = [
                { $0 },
                { $0.replacingOccurrences(of: " ", with: "") },
                { $0.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "") },
                {
                    $0.replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "(", with: "")
                        .replacingOccurrences(of: ")", with: "")
                }
            ]

            for transform in transformations {
                let value = transform(name)
                if !value.isEmpty, seenVariants.insert(value).inserted {
                    results.append(value)
                }
            }

            return results
        }

        var baseNames = [assetName]
        if let iconName {
            baseNames.append(iconName)
        }
        baseNames.append(contentsOf: additionalImageNames)

        for name in baseNames {
            for variant in sanitizedVariants(for: name) {
                append(variant)
                let stripped = stripScaleSuffix(from: variant)
                if stripped != variant {
                    append(stripped)
                }
            }
        }

        return candidates
    }
}

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public enum AppResources {
    public static var appIconImage: Image {
        #if os(macOS)
        if let image = NSImage(named: NSImage.applicationIconName) {
            return Image(nsImage: image)
        }
        #else
        if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String,
           let image = UIImage(named: iconName) {
            return Image(uiImage: image)
        }
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcons = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcons["CFBundleIconFiles"] as? [String],
           let iconName = iconFiles.last,
           let image = UIImage(named: iconName) {
            return Image(uiImage: image)
        }
        #endif
        return Image(systemName: "gearshape.fill")
    }
}
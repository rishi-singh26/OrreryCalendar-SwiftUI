//
//  AppIconOption.swift
//  Orrery
//
//  Alternate app icon support. `UIApplication.setAlternateIconName` has no macOS
//  equivalent, so this whole file compiles out on macOS.
//

#if os(iOS)
import UIKit

/// The app icons declared under `CFBundleIcons` in Info.plist.
enum AppIconOption: String, CaseIterable, Identifiable {
    case primary
    case two

    var id: String { rawValue }

    /// Name passed to `UIApplication.setAlternateIconName(_:)`. `nil` requests the
    /// primary icon, which is how the API expects the default to be selected.
    var iconName: String? {
        switch self {
        case .primary: return nil
        case .two: return "AppIconTwo"
        }
    }

    /// Plain (non-appiconset) image asset used to preview the icon in Settings.
    /// `UIImage(named:)` can't render an "app icon" asset catalog entry directly,
    /// so each option keeps a matching flat image for display purposes.
    var previewImageName: String {
        switch self {
        case .primary: return "AppIconImage"
        case .two: return "AppIconTwoImage"
        }
    }

    var displayName: String {
        switch self {
        case .primary: return "Default"
        case .two: return "Orbit"
        }
    }

    /// The option matching the app's currently active icon.
    static var current: AppIconOption {
        guard let name = UIApplication.shared.alternateIconName else { return .primary }
        return AppIconOption.allCases.first { $0.iconName == name } ?? .primary
    }

    /// Asks the system to switch to this icon. `completion` is always called on the
    /// main queue with any error the system reported.
    func apply(completion: @escaping (Error?) -> Void) {
        guard UIApplication.shared.alternateIconName != iconName else {
            completion(nil)
            return
        }
        guard UIApplication.shared.supportsAlternateIcons else {
            completion(nil)
            return
        }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if Thread.isMainThread {
                completion(error)
            } else {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
}
#endif

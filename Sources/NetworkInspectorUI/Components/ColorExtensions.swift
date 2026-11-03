import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    public static var inspectorBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.primary
        #endif
    }

    public static var inspectorSecondaryBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.gray.opacity(0.15)
        #endif
    }

    public static var inspectorCardBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .underPageBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }

    public static var inspectorTertiaryFill: Color {
        #if canImport(UIKit)
        return Color(uiColor: .tertiarySystemFill)
        #elseif canImport(AppKit)
        return Color(nsColor: .separatorColor)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }

    public static var inspectorCardBorder: Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.black.withAlphaComponent(0.08)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.12)
                : NSColor.black.withAlphaComponent(0.08)
        })
        #else
        return Color.gray.opacity(0.15)
        #endif
    }

    public static var inspectorCodeBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
                : UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
                : NSColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        })
        #else
        return Color.gray.opacity(0.12)
        #endif
    }

    public static var inspectorMutedFill: Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.07)
                : UIColor.black.withAlphaComponent(0.04)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.07)
                : NSColor.black.withAlphaComponent(0.04)
        })
        #else
        return Color.gray.opacity(0.05)
        #endif
    }
}

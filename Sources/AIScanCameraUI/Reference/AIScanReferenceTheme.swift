import UIKit

enum AIScanReferenceTheme {
    static var background: UIColor { adaptive(light: .white, dark: .systemBackground) }
    static var surface: UIColor { adaptive(light: .white, dark: .secondarySystemBackground) }
    static var surfaceSecondary: UIColor {
        adaptive(light: rgb(0xF5F6F8), dark: .tertiarySystemBackground)
    }
    static var textPrimary: UIColor { adaptive(light: rgb(0x191919), dark: .label) }
    static var textSecondary: UIColor { adaptive(light: rgb(0x717171), dark: .secondaryLabel) }
    static var textTertiary: UIColor { adaptive(light: rgb(0x999999), dark: .tertiaryLabel) }
    static var bodyText: UIColor { adaptive(light: rgb(0x535353), dark: .secondaryLabel) }
    static var dateText: UIColor { adaptive(light: rgb(0x898989), dark: .secondaryLabel) }
    static var noticeText: UIColor { adaptive(light: rgb(0xB4B4B4), dark: .tertiaryLabel) }
    static var divider: UIColor { adaptive(light: rgb(0xEDEDED), dark: .separator) }
    static var controlBorder: UIColor { adaptive(light: rgb(0xEBEDF0), dark: .separator) }
    static var albumUnselectedAction: UIColor {
        adaptive(light: rgb(0x173DB0).withAlphaComponent(0.5), dark: brandPrimary)
    }
    static var warning: UIColor { adaptive(light: .red, dark: .systemRed) }
    static var shadow: UIColor { adaptive(light: .black, dark: .black) }
    static var skinSpacer: UIColor { adaptive(light: rgb(0xF4F4F4), dark: .tertiarySystemBackground) }
    static var brandPrimary: UIColor { named("AISBrandPrimary", fallback: .systemBlue) }
    static var brandAccent: UIColor { named("AISBrandAccent", fallback: .systemBlue) }
    static var brandTint: UIColor { named("AISBrandTint", fallback: .secondarySystemBackground) }
    static var disabledSurface: UIColor { named("AISDisabledSurface", fallback: .systemGray5) }
    static var onBrand: UIColor { named("AISOnBrand", fallback: .white) }

    static var selectedChip: UIColor { brandAccent }
    static var selectedChipText: UIColor { onBrand }
    static var unselectedChipBackground: UIColor {
        surfaceSecondary
    }
    static var unselectedChipBorder: UIColor {
        adaptive(light: rgb(0xD3D3D3), dark: .separator)
    }
    static let unselectedChipBorderWidth: CGFloat = 1
    static var originalCaptionBackground: UIColor {
        adaptive(light: rgb(0xAAB1D1), dark: brandTint)
    }
    static var originalCaptionText: UIColor {
        adaptive(light: .white, dark: brandPrimary)
    }
    static var analysisCaptionBackground: UIColor {
        adaptive(light: rgb(0x23335C), dark: brandPrimary)
    }
    static var analysisCaptionText: UIColor {
        adaptive(light: .white, dark: onBrand)
    }
    static var exportAction: UIColor {
        adaptive(light: rgb(0x06ACC7), dark: brandPrimary)
    }
    static var skeletonBase: UIColor {
        adaptive(light: rgb(0xE9E9E9), dark: .tertiarySystemBackground)
    }
    static var skeletonHighlight: UIColor {
        adaptive(light: .white, dark: .separator)
    }

    static func resolvedCGColor(_ color: UIColor, traits: UITraitCollection) -> CGColor {
        color.resolvedColor(with: traits).cgColor
    }

    private static func named(_ name: String, fallback: UIColor) -> UIColor {
        UIColor(
            named: name,
            in: AIScanReferenceStrings.resourceBundle,
            compatibleWith: nil
        ) ?? fallback
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            let color = traits.userInterfaceStyle == .dark ? dark : light
            return color.resolvedColor(with: traits)
        }
    }

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

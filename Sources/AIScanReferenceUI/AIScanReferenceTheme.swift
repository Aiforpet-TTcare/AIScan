import UIKit

enum AIScanReferenceTheme {
    static var background: UIColor { adaptive(light: .white, dark: .systemBackground) }
    static var surface: UIColor { adaptive(light: .white, dark: .secondarySystemBackground) }
    static var surfaceSecondary: UIColor {
        adaptive(light: rgb(0xF5F6F8), dark: .secondarySystemBackground)
    }
    static var textPrimary: UIColor { adaptive(light: rgb(0x191919), dark: .label) }
    static var textSecondary: UIColor { adaptive(light: rgb(0x717171), dark: .secondaryLabel) }
    static var divider: UIColor { adaptive(light: rgb(0xEDEDED), dark: .separator) }
    static var selectedChip: UIColor {
        adaptive(light: rgb(0x173DB0), dark: rgb(0x6D8DFF))
    }
    static var selectedChipText: UIColor {
        adaptive(light: .white, dark: .black)
    }
    static var unselectedChipBackground: UIColor {
        adaptive(light: .white, dark: .secondarySystemBackground)
    }
    static var unselectedChipBorder: UIColor {
        adaptive(light: rgb(0xD3D3D3), dark: .separator)
    }
    static let unselectedChipBorderWidth: CGFloat = 1
    static var originalCaptionBackground: UIColor {
        adaptive(light: rgb(0xEEF4FF), dark: rgb(0x26304A))
    }
    static var originalCaptionText: UIColor {
        selectedChip
    }
    static var analysisCaptionBackground: UIColor {
        adaptive(light: rgb(0x23335C), dark: rgb(0x6D8DFF))
    }
    static var analysisCaptionText: UIColor {
        selectedChipText
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

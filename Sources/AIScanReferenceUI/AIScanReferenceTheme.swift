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
    static var bodyText: UIColor { adaptive(light: rgb(0x717171), dark: .secondaryLabel) }
    static var noticeText: UIColor { adaptive(light: rgb(0x8B8B8B), dark: .tertiaryLabel) }
    static var dateText: UIColor { adaptive(light: rgb(0x8B8B8B), dark: .secondaryLabel) }
    static var dateBackground: UIColor {
        adaptive(light: rgb(0xF7F7FA), dark: .secondarySystemBackground)
    }
    static var dateBorder: UIColor { adaptive(light: rgb(0xD4D4D8), dark: .separator) }
    static var sectionIcon: UIColor {
        adaptive(light: rgb(0x3867F4), dark: rgb(0x6D8DFF))
    }
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
    static var statusBoardBorder: UIColor {
        adaptive(light: rgb(0xF4F4FA), dark: rgb(0x202126))
    }
    static var statusBoardBackground: UIColor {
        adaptive(light: rgb(0x28385F), dark: rgb(0x28385F))
    }

    static func statusColor(_ style: AIScanDisplayStatusStyle) -> UIColor {
        switch style {
        case .normal:
            rgb(0x3E6CB7)
        case .caution:
            rgb(0xFF7043)
        case .warning:
            rgb(0x9A4665)
        }
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

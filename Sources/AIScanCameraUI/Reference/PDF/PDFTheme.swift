//
//  PDFTheme.swift
//  AIScan
//
//  Geometry, colors, spacing, and Pretendard font helpers for the screening
//  PDF report. Values mirror the original web report kit's PDF styles
//  (`source/report/pdf/common.ts` and the per-page `@react-pdf/renderer`
//  inline styles) so the iOS output matches the reference design pixel-for-pixel
//  at A4 595x842 @ 72dpi.
//

import SwiftUI
import UIKit

enum PDFTheme {

    // MARK: - Page geometry

    /// A4 at 72dpi (210x297mm).
    static let pageSize = CGSize(width: 595, height: 842)

    // Body content padding (layout.tsx body): top 60, bottom 50, horizontal 30.
    static let bodyPaddingTop: CGFloat = 60
    static let bodyPaddingBottom: CGFloat = 50
    static let bodyPaddingLeft: CGFloat = 30
    static let bodyPaddingRight: CGFloat = 30

    // Fixed header (50pt tall) and footer band.
    static let headerHeight: CGFloat = 50
    static let footerHeight: CGFloat = 35

    // MARK: - Colors (exact hex from the kit)

    static let ink = color(0x191919)            // primary text
    static let navy = color(0x33488c)           // section/body accent text
    static let red = color(0xfa535f)            // abnormal
    static let blue = color(0x368df5)           // normal
    static let slate = color(0xa0aaca)          // abnormal-sign header cell
    static let panel = color(0xe7e9ef)          // section title / table cell bg
    static let notePink = color(0xfff0f1)       // warning note background
    static let gray = color(0x939393)           // footer / muted text

    static let white = Color.white

    static func color(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0
        )
    }

    // MARK: - Fonts (Pretendard, registered by FontRegistrar)

    enum Weight {
        case regular, medium, bold

        var postScriptName: String {
            switch self {
            case .regular: return "Pretendard-Regular"
            case .medium:  return "Pretendard-Medium"
            case .bold:    return "Pretendard-Bold"
            }
        }
    }

    /// SwiftUI Font in the requested Pretendard weight/size. Falls back to the
    /// system font automatically if registration ever failed.
    static func font(_ weight: Weight, _ size: CGFloat) -> Font {
        .custom(weight.postScriptName, size: size)
    }
}

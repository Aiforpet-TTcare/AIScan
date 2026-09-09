//
//  PDFComponents.swift
//  AIScan
//
//  Shared SwiftUI building blocks for the screening PDF pages: the bundled-image
//  loader, the remote/local diagnosis image (with gray placeholder fallback),
//  the section title bar, the layout header/footer, and the check-mark badges.
//  All geometry/colors mirror the kit's `@react-pdf/renderer` styles.
//

import SwiftUI
import UIKit

// MARK: - Resolved image store

/// Carries pre-downloaded UIImages keyed by source URL into the render pass.
struct PDFResolvedImages {
    let images: [URL: UIImage]
    func image(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        return images[url]
    }
}

// MARK: - Bundled PDF asset image

/// Loads a static PNG from the SDK's `Resources/pdf` folder by base name
/// (without the `@2x` suffix / extension).
struct PDFAssetImage: View {
    let name: String
    var width: CGFloat
    var height: CGFloat
    /// When set, the asset is drawn as a template tinted to this color
    /// (used for the dark cover where a black wordmark must render white).
    var tint: Color? = nil

    var body: some View {
        Group {
            if let image = PDFAssetImage.load(name) {
                if let tint {
                    SwiftUI.Image(uiImage: image.withRenderingMode(.alwaysTemplate))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: width, height: height)
                        .foregroundColor(tint)
                } else {
                    SwiftUI.Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: width, height: height)
                }
            } else {
                Color.clear.frame(width: width, height: height)
            }
        }
    }

    static func load(_ baseName: String) -> UIImage? {
        let bundle = AIScanReferenceStrings.resourceBundle
        // Assets were copied with a `@2x` suffix; try both forms.
        for candidate in ["\(baseName)@2x", baseName] {
            if let url = bundle.url(forResource: candidate, withExtension: "png", subdirectory: "PDF/Assets"),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
            if let url = bundle.url(forResource: candidate, withExtension: "png"),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
}

// MARK: - Diagnosis (remote/local) image with placeholder

/// Renders a resolved diagnosis image, or a gray rounded placeholder box when
/// the image is missing.
struct PDFDiagnosisImage: View {
    let url: URL?
    let resolved: PDFResolvedImages
    var size: CGFloat
    var cornerRadius: CGFloat = 15

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(PDFTheme.panel)
            if let image = resolved.image(for: url) {
                SwiftUI.Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Check badge (summary table)

struct PDFCheckMark: View {
    let color: Color
    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            SwiftUI.Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
        }
        .overlay(Circle().stroke(color, lineWidth: 1.5))
        .frame(width: 17, height: 17)
    }
}

// MARK: - Section title

/// The blue-on-panel section header used across detail/comprehensive pages.
struct PDFSectionTitle: View {
    let title: String
    var imageName: String?
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 0) {
                if let imageName {
                    PDFAssetImage(name: imageName, width: 19, height: 19)
                        .padding(.trailing, 7)
                }
                Text(title)
                    .font(PDFTheme.font(.bold, 13))
                    .foregroundColor(PDFTheme.navy)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let subtitle {
                Text(subtitle)
                    .font(PDFTheme.font(.regular, 10))
                    .foregroundColor(PDFTheme.navy)
                    .padding(.leading, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(PDFTheme.panel))
    }
}

// MARK: - Bulleted line

/// A bullet-prefixed text row for the comprehensive page sections.
/// `leading` (bold) is the symptom name; `body` is the descriptive text.
struct PDFBulletLine: View {
    let leading: String?
    let text: String

    init(leading: String? = nil, body: String) {
        self.leading = leading
        self.text = body
    }

    private var attributedContent: Text {
        if let leading {
            return Text(leading + " ").font(PDFTheme.font(.bold, 12))
                + Text(text).font(PDFTheme.font(.regular, 12))
        } else {
            return Text(text).font(PDFTheme.font(.regular, 12))
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("• ")
                .font(PDFTheme.font(.regular, 12))
                .foregroundColor(PDFTheme.navy)
            attributedContent
                .foregroundColor(PDFTheme.navy)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

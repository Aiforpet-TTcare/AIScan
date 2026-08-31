//
//  FontRegistrar.swift
//  AIScan
//
//  Registers the bundled Pretendard fonts at runtime so the PDF report can
//  render with the same typeface as the original web report kit. The SDK ships
//  as a framework and therefore cannot declare `UIAppFonts` in the host app's
//  Info.plist; instead it registers the ttf files against its own bundle via
//  `CTFontManagerRegisterFontsForURL`.
//

import UIKit
import CoreText

enum FontRegistrar {

    /// Logical Pretendard family name once registered (PostScript family).
    static let familyName = "Pretendard"

    private static var didRegister = false
    private static let lock = NSLock()

    /// Lazily registers the three Pretendard weights. Safe to call repeatedly;
    /// registration happens only once. Must run before the first PDF render.
    static func registerIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        let bundle = AIScanReferenceStrings.resourceBundle
        let fontFiles = [
            "Pretendard-Regular",
            "Pretendard-Medium",
            "Pretendard-Bold"
        ]
        for name in fontFiles {
            let url = bundle.url(
                forResource: name,
                withExtension: "ttf",
                subdirectory: "PDF/Fonts"
            ) ?? bundle.url(forResource: name, withExtension: "ttf")
            guard let url else {
                continue
            }
            var errorRef: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef) {
                // Already-registered is benign across SDK instances.
                _ = errorRef?.takeRetainedValue()
            }
        }
    }
}

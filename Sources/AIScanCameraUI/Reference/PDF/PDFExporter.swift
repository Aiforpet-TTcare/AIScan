//
//  PDFExporter.swift
//  AIScan
//
//  Renders an ordered list of A4-sized SwiftUI pages to a multi-page PDF via
//  CGContext. Ported from the dogtopia_wellness PDFExporter (ImageRenderer ->
//  beginPDFPage/render/endPDFPage), with a UIHostingController +
//  UIGraphicsImageRenderer fallback for iOS < 16 (the SDK deployment target is
//  iOS 15, and `ImageRenderer` requires iOS 16). Light color scheme and a 2.0
//  display scale keep text crisp.
//

import SwiftUI
import UIKit

enum PDFExporter {

    /// Renders the given pages into a PDF at `url`. Returns the URL on success.
    @MainActor
    static func export(pages: [any View], to url: URL) -> URL? {
        var mediaBox = CGRect(origin: .zero, size: PDFTheme.pageSize)
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return nil }

        for page in pages {
            let wrapped = AnyView(
                page
                    .frame(width: PDFTheme.pageSize.width, height: PDFTheme.pageSize.height)
                    .environment(\.colorScheme, .light)
            )
            ctx.beginPDFPage(nil)
            renderPage(wrapped, into: ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }

    @MainActor
    private static func renderPage(_ view: AnyView, into ctx: CGContext) {
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2.0
            renderer.isOpaque = true
            renderer.render { _, render in
                render(ctx)
            }
        } else {
            renderPageLegacy(view, into: ctx)
        }
    }

    /// iOS 15 fallback: host the SwiftUI view, snapshot it into a UIImage at 2x,
    /// then draw the image into the PDF page rect.
    @MainActor
    private static func renderPageLegacy(_ view: AnyView, into ctx: CGContext) {
        let size = PDFTheme.pageSize
        let host = UIHostingController(rootView: view)
        host.view.bounds = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = .white
        if #available(iOS 13.0, *) {
            host.overrideUserInterfaceStyle = .light
        }

        // Force layout.
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = true
        let imageRenderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = imageRenderer.image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }

        // CoreGraphics PDF origin is bottom-left; flip before drawing the image.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        if let cg = image.cgImage {
            ctx.draw(cg, in: CGRect(origin: .zero, size: size))
        }
        ctx.restoreGState()

        window.isHidden = true
        window.rootViewController = nil
    }
}

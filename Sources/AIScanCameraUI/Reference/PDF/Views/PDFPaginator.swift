//
//  PDFPaginator.swift
//  AIScan
//
//  Measured greedy pagination for the screening PDF. Mirrors the reference
//  pdf-kit's @react-pdf block-level auto-flow: content is decomposed into
//  atomic, never-split BLOCKS; each block is MEASURED at the A4 content width;
//  blocks are greedily packed into pages so anything that doesn't fit starts a
//  new page. This replaces the previous fixed single-page Detail/Comprehensive
//  views that clipped when a part had many symptoms.
//

import SwiftUI
import UIKit

/// One atomic, never-split unit of page content together with its measured
/// height at the A4 content width.
struct PDFBlock: Identifiable {
    let id = UUID()
    /// The rendered content. Erased so heterogeneous blocks share one array.
    let view: AnyView
    /// Measured height at `PDFPaginator.contentWidth`.
    let height: CGFloat
}

/// A packed page: the title shown in the header band plus its ordered blocks.
struct PDFPlacedPage {
    let pageTitle: String
    let blocks: [PDFBlock]
}

enum PDFPaginator {

    // MARK: - Geometry

    /// A4 width (595) minus the body horizontal padding (left 30 + right 30).
    static let contentWidth: CGFloat = PDFTheme.pageSize.width
        - PDFTheme.bodyPaddingLeft - PDFTheme.bodyPaddingRight   // 535

    /// Usable vertical space for packed blocks on a single page. The body VStack
    /// starts at `bodyPaddingTop` (60) and the header band is drawn OVER the top
    /// 50pt — since the body already begins at 60, the header does NOT reduce
    /// content and must NOT be subtracted again (doing so wrongly shaved ~90pt
    /// and packed only 2 detail symptoms per page where the reference fits 3).
    /// Only the footer intrudes from the bottom.
    ///   842 − top60 − footerReserve62 = 720
    static let contentHeight: CGFloat = PDFTheme.pageSize.height
        - PDFTheme.bodyPaddingTop       // 60
        - PDFPaginator.footerReserve    // 62

    /// Vertical room reserved at the bottom for the footer band (CI + page no.).
    /// The footer is ~35pt tall and sits 25pt off the bottom (≈60 from the page
    /// edge); 62 keeps the last block clear of it.
    static let footerReserve: CGFloat = 62

    // MARK: - Measurement

    /// Measures a SwiftUI view's height when laid out at `contentWidth`.
    /// Uses a `UIHostingController` + Auto Layout fitting size, exactly like the
    /// result screen's self-sizing cells. Must run on the main actor.
    @MainActor
    static func measure<V: View>(_ view: V) -> CGFloat {
        let host = UIHostingController(rootView: view.frame(width: contentWidth))
        host.view.backgroundColor = .clear
        let target = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        let size = host.view.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(size.height)
    }

    /// Wraps a view into a measured `PDFBlock`.
    @MainActor
    static func block<V: View>(_ view: V) -> PDFBlock {
        PDFBlock(view: AnyView(view), height: measure(view))
    }

    // MARK: - Packing

    /// Greedily packs blocks into pages: a block that does not fit in the
    /// remaining space starts a new page. A block taller than a whole page is
    /// allowed to occupy its own page (it is never split).
    static func pack(title: String, blocks: [PDFBlock]) -> [PDFPlacedPage] {
        guard !blocks.isEmpty else { return [] }
        var pages: [PDFPlacedPage] = []
        var current: [PDFBlock] = []
        var used: CGFloat = 0

        for block in blocks {
            let fits = used + block.height <= contentHeight
            if !current.isEmpty && !fits {
                pages.append(PDFPlacedPage(pageTitle: title, blocks: current))
                current = []
                used = 0
            }
            current.append(block)
            used += block.height
        }
        if !current.isEmpty {
            pages.append(PDFPlacedPage(pageTitle: title, blocks: current))
        }
        return pages
    }
}

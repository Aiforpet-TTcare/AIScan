//
//  PDFBlockPageView.swift
//  AIScan
//
//  Renders one paginated page: a list of pre-measured, greedily-packed blocks
//  wrapped in the shared `PDFPageLayout` (header band + footer with the dynamic
//  "x / total" page number). Used by the Summary / Detail / Comprehensive flows
//  after `PDFPaginator.pack(...)` decides which blocks land on which page.
//

import SwiftUI

struct PDFBlockPageView: View {
    let part: String
    let page: PDFPlacedPage
    let pageNumber: Int
    let totalPages: Int

    var body: some View {
        PDFPageLayout(
            part: part,
            pageTitle: page.pageTitle,
            pageNumber: pageNumber,
            totalPages: totalPages
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(page.blocks) { block in
                    block.view
                }
            }
        }
    }
}

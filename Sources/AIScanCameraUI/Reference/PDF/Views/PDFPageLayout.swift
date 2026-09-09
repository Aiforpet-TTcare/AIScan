//
//  PDFPageLayout.swift
//  AIScan
//
//  A4 page chrome shared by the summary/detail/comprehensive pages: a fixed
//  top header band (navy background image + "<part> - <title>" text) and a
//  footer (TTcareVet CI + info message + page number). Ports `layout.tsx`.
//

import SwiftUI

struct PDFPageLayout<Content: View>: View {
    let part: String
    let pageTitle: String
    let pageNumber: Int
    let totalPages: Int
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            Color.white

            // Body content within the kit's padding (top 60 / bottom 50 / h 30).
            VStack(alignment: .leading, spacing: 0) {
                content()
                Spacer(minLength: 0)
            }
            .padding(.top, PDFTheme.bodyPaddingTop)
            .padding(.bottom, PDFTheme.bodyPaddingBottom)
            .padding(.leading, PDFTheme.bodyPaddingLeft)
            .padding(.trailing, PDFTheme.bodyPaddingRight)
            .frame(width: PDFTheme.pageSize.width, height: PDFTheme.pageSize.height, alignment: .top)

            header
            VStack {
                Spacer()
                footer
            }
        }
        .frame(width: PDFTheme.pageSize.width, height: PDFTheme.pageSize.height)
        .background(Color.white)
    }

    private var header: some View {
        ZStack {
            PDFAssetImage(name: "sub-back-img", width: PDFTheme.pageSize.width, height: PDFTheme.headerHeight)
            HStack {
                Text(PDFStrings.headerTitle(part: part, pageTitle: pageTitle))
                    .font(PDFTheme.font(.bold, 13))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .frame(width: PDFTheme.pageSize.width, height: PDFTheme.headerHeight)
    }

    private var footer: some View {
        HStack(alignment: .center) {
            HStack(spacing: 4) {
                PDFAssetImage(name: "ttcarevet-ci", width: 42, height: 8)
                Text(PDFStrings.infoMessage)
                    .font(PDFTheme.font(.regular, 9))
                    .foregroundColor(PDFTheme.gray)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(pageNumber) / \(totalPages)")
                .font(PDFTheme.font(.medium, 10))
                .foregroundColor(PDFTheme.ink)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 25)
        .frame(width: PDFTheme.pageSize.width)
    }
}

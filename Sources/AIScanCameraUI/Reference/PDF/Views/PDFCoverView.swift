//
//  PDFCoverView.swift
//  AIScan
//
//  Cover page. Ports `cover.tsx`: full-bleed background, pet emoji, big cover
//  title, pet detail line, then a bordered info table. Per SDK scope the
//  hospital name and its table row are omitted (the SDK does not know it); the
//  table keeps the print-date and examination-date rows only.
//

import SwiftUI

struct PDFCoverView: View {
    let props: ScreeningPdfProps

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = props.locale == .ko ? Locale(identifier: "ko_KR") : Locale(identifier: "en_US")
        f.dateFormat = props.locale == .ko ? "yyyy. M. d a h:mm" : "MMM d, yyyy h:mm a"
        return f
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Full-bleed background.
            PDFAssetImage(name: "back-img", width: PDFTheme.pageSize.width, height: PDFTheme.pageSize.height)

            VStack(alignment: .leading, spacing: 0) {
                PDFAssetImage(name: props.isDog ? "dog-emoji" : "cat-emoji", width: 60, height: 60)
                    .offset(x: -5)
                    .padding(.bottom, 10)

                Text(PDFStrings.coverTitleMultiline)
                    .font(PDFTheme.font(.bold, 54))
                    .foregroundColor(.white)
                    .lineSpacing(0)
                    .fixedSize(horizontal: false, vertical: true)

                Text(props.petDetail)
                    .font(PDFTheme.font(.medium, 16))
                    .foregroundColor(.white)
                    .padding(.top, 15)

                Spacer().frame(height: 175)

                infoTable
                    .padding(.leading, 5)
            }
            .padding(.top, 150)
            .padding(.horizontal, 60)

            VStack {
                Spacer()
                PDFAssetImage(name: "ttcarevet-ci-white", width: 69, height: 13, tint: .white)
                    .padding(.leading, 65)
                    .padding(.bottom, 60)
            }
        }
        .frame(width: PDFTheme.pageSize.width, height: PDFTheme.pageSize.height)
        .background(Color.white)
    }

    private var examinationDateText: String {
        let part = PDFStrings.partLabel(props.part)
        return "\(part): \(dateFormatter.string(from: props.diagnoses.createdAt))"
    }

    private var infoTable: some View {
        VStack(spacing: 0) {
            // Header row: print-date | examination-date labels.
            HStack(spacing: 0) {
                tableCell(PDFStrings.printDateLabel, weight: .regular)
                tableCell(PDFStrings.examinationDateLabel, weight: .regular)
            }
            // Value row: print date | examination (part: date).
            HStack(spacing: 0) {
                tableCell(dateFormatter.string(from: props.printDate), weight: .bold)
                tableCell(examinationDateText, weight: .bold)
            }
        }
        .frame(width: 350)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func tableCell(_ text: String, weight: PDFTheme.Weight) -> some View {
        Text(text)
            .font(PDFTheme.font(weight, 10))
            .foregroundColor(.white)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, minHeight: 25, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
    }
}

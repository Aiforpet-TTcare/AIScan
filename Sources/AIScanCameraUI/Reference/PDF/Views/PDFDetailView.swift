//
//  PDFDetailView.swift
//  AIScan
//
//  Detailed AI Analysis page. Ports `detail-content.tsx`: a section title with
//  subtitle, then one block per symptom (colored name badge, detail copy,
//  origin CAM thumbnails with an abnormal red ring + check badge, then a paw
//  divider).
//

import SwiftUI

struct PDFDetailView {
    let props: ScreeningPdfProps
    let resolved: PDFResolvedImages

    /// Atomic, never-split blocks for the Detail page: the section-title header
    /// block followed by one block per symptom (badge + copy + heatmap grid +
    /// paw divider). Each block bakes in its own top/bottom spacing so the
    /// measured height the paginator packs against is exact.
    @MainActor
    func blocks() -> [PDFBlock] {
        var result: [PDFBlock] = []
        result.append(PDFPaginator.block(
            PDFSectionTitle(
                title: PDFStrings.detailTitle,
                imageName: "search-illust",
                subtitle: PDFStrings.detailDescription
            )
            .padding(.top, 20)
            .padding(.bottom, 10)
        ))
        for symptom in props.diagnoses.symptoms {
            result.append(PDFPaginator.block(
                symptomBlock(symptom).padding(.top, 10)
            ))
        }
        return result
    }

    @ViewBuilder
    private func symptomBlock(_ symptom: ScreeningPdfSymptom) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(symptom.name)
                    .font(PDFTheme.font(.bold, 11))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(symptom.isAbnormal ? PDFTheme.red : PDFTheme.blue))
                Spacer()
            }

            Text(symptom.isAbnormal ? symptom.description.detail : PDFStrings.detailNotDetected)
                .font(PDFTheme.font(.regular, 12))
                .foregroundColor(PDFTheme.navy)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 14)

            // Per position: the scanned crop ("촬영 이미지") on the LEFT and the AI
            // heatmap ("AI 분석 이미지") on the RIGHT, each captioned below.
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(symptom.origin.enumerated()), id: \.offset) { _, origin in
                    captionedImage(url: origin.capturedImageUrl,
                                   caption: PDFStrings.capturedImageTitle,
                                   showRing: false)
                    captionedImage(url: origin.camImageUrl,
                                   caption: PDFStrings.analysisImageTitle,
                                   showRing: origin.isAbnormal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Paw divider.
            HStack(spacing: 3) {
                Rectangle().fill(PDFTheme.navy).frame(height: 1)
                PDFPawIcon().frame(width: 13, height: 13)
                Rectangle().fill(PDFTheme.navy).frame(height: 1)
            }
            .padding(.top, 10)
        }
    }

    /// A 90pt diagnosis image with a centered caption below. `showRing` draws the
    /// red abnormal ring + check badge (used for the AI analysis image only).
    @ViewBuilder
    private func captionedImage(url: URL?, caption: String, showRing: Bool) -> some View {
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                PDFDiagnosisImage(url: url, resolved: resolved, size: 90)
                if showRing {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(PDFTheme.red, lineWidth: 3)
                        .frame(width: 90, height: 90)
                    ZStack {
                        Circle().fill(PDFTheme.red)
                        SwiftUI.Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 18, height: 18)
                    .offset(x: 3, y: -3)
                }
            }
            Text(caption)
                .font(PDFTheme.font(.bold, 12))
                .foregroundColor(PDFTheme.ink)
        }
    }
}

/// Minimal paw glyph used as the section divider (matches the kit's inline SVG).
struct PDFPawIcon: View {
    var body: some View {
        ZStack {
            Circle().fill(PDFTheme.navy).frame(width: 6, height: 6).offset(y: 3)
            Circle().fill(PDFTheme.navy).frame(width: 3, height: 3).offset(x: -3.5, y: -2)
            Circle().fill(PDFTheme.navy).frame(width: 2.6, height: 2.6).offset(x: 0.5, y: -3.5)
            Circle().fill(PDFTheme.navy).frame(width: 2.1, height: 2.1).offset(x: 4, y: -1.5)
            Circle().fill(PDFTheme.navy).frame(width: 2.6, height: 2.6).offset(x: -4.5, y: 0)
        }
    }
}

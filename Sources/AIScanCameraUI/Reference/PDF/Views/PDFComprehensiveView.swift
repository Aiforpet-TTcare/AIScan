//
//  PDFComprehensiveView.swift
//  AIScan
//
//  Comprehensive AI-based Guidance page. Ports `comprehensive-content.tsx`:
//  cause + recommended-inspection sections (abnormal only), a warning section,
//  a home-care ("following") section, and a red note box. Abnormal symptom
//  copy comes from the per-symptom description; normal-case warning/care text
//  comes from the ported message catalog.
//
//  Block model mirrors the reference `comprehensive-content.tsx` EXACTLY: every
//  section there is wrapped in a single `<View wrap={false}>` (cause /
//  recommendation / warning / following), so a section is ONE atomic,
//  never-split block here — title and all its bullets travel together. The red
//  note box is its own `wrap={false}` block. The paginator greedily packs these
//  section-blocks, reproducing the reference's per-part page counts instead of
//  re-flowing bullet-by-bullet (which packed tighter and broke the counts).
//

import SwiftUI

struct PDFComprehensiveView {
    let props: ScreeningPdfProps

    private var diagnoses: ScreeningPdfDiagnosesData { props.diagnoses }

    /// Section-atomic blocks for the Comprehensive page, in render order. Each
    /// section is ONE block (title + all its bullets), mirroring the reference's
    /// per-section `wrap={false}`. The abnormal symptom list is the FULL set of
    /// abnormal findings (the adapter now carries the whole catalog, so filter
    /// to abnormal here exactly like the reference's `diagnoses.symptoms`).
    @MainActor
    func blocks() -> [PDFBlock] {
        var result: [PDFBlock] = []
        let abnormal = diagnoses.symptoms.filter { $0.isAbnormal }

        if diagnoses.isAbnormal {
            result.append(PDFPaginator.block(sectionView(
                title: PDFStrings.comprehensiveCause,
                imageName: "bubble-illust",
                bullets: abnormal.map {
                    PDFBulletLine(leading: $0.name, body: $0.description.cause)
                }
            )))
            result.append(PDFPaginator.block(sectionView(
                title: PDFStrings.comprehensiveRecommendation,
                imageName: "examination-illust",
                bullets: abnormal.map {
                    PDFBulletLine(leading: $0.name, body: $0.description.inspection)
                }
            )))
        }

        result.append(PDFPaginator.block(sectionView(
            title: PDFStrings.comprehensiveWarning,
            imageName: "vet-illust",
            bullets: diagnoses.warningLines.map { PDFBulletLine(body: $0) }
        )))

        let followingBullets: [PDFBulletLine] = diagnoses.isAbnormal
            ? abnormal.map { PDFBulletLine(leading: $0.name, body: $0.description.care) }
            : diagnoses.careNormalLines.map { PDFBulletLine(body: $0) }
        result.append(PDFPaginator.block(sectionView(
            title: PDFStrings.comprehensiveFollowing,
            imageName: "home-illust",
            bullets: followingBullets,
            bottomPadding: 20
        )))

        result.append(PDFPaginator.block(noteBox))
        return result
    }

    // MARK: - Block builders

    /// One whole section (title + every bullet) as a single never-split view,
    /// mirroring the reference's `<View wrap={false}>` wrapper. Keeps the kit's
    /// section spacing (top 20) and the bullets' inset (h 10, first top 15).
    private func sectionView(
        title: String,
        imageName: String,
        bullets: [PDFBulletLine],
        bottomPadding: CGFloat = 0
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PDFSectionTitle(title: title, imageName: imageName)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { index, bullet in
                    bullet
                        .padding(.top, index == 0 ? 15 : 0)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 20)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noteBox: some View {
        HStack(alignment: .top, spacing: 4) {
            ZStack {
                Circle().stroke(PDFTheme.red, lineWidth: 1.2)
                SwiftUI.Image(systemName: "exclamationmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(PDFTheme.red)
            }
            .frame(width: 12, height: 12)
            .padding(.top, 2)

            Text(PDFStrings.comprehensiveNote)
                .font(PDFTheme.font(.regular, 11))
                .foregroundColor(PDFTheme.red)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(PDFTheme.notePink))
    }
}

//
//  PDFSummaryView.swift
//  AIScan
//
//  AI Analysis Summary page. Ports `summary-content.tsx`: intro paragraph with
//  illustration, a section title, the position thumbnail grid, and the
//  abnormal-sign table (symptom rows with abnormal/normal check columns).
//
//  Decomposed into atomic blocks for measured pagination. The summary usually
//  fits on one page, so the table is kept as a SINGLE block (preserving its
//  rounded-corner clip). Only if the intro + grid + whole table overflow one
//  page does it fall back to splitting the table into per-row blocks (header
//  row + one block per symptom row) so nothing is clipped.
//

import SwiftUI

struct PDFSummaryView {
    let props: ScreeningPdfProps
    let resolved: PDFResolvedImages

    // 30pt rows for every part (eye/tooth/skin) so the table density is uniform
    // and skin's extra "피부 상태 상세" feature card fits on the summary page.
    private let rowHeight: CGFloat = 30
    private let cellSpacing: CGFloat = 1

    /// Atomic blocks for the Summary page. Keeps the table whole when it fits;
    /// splits into per-row blocks otherwise.
    @MainActor
    func blocks() -> [PDFBlock] {
        let intro = PDFPaginator.block(self.intro)
        let title = PDFPaginator.block(sectionTitle.padding(.bottom, 20))
        let grid = PDFPaginator.block(positionsGrid)

        // Skin-feature card (sensitivity/dryness/roughness) under the table —
        // SKIN reports only; empty on eye/tooth so nothing extra is emitted.
        let skinBlock: PDFBlock? = props.diagnoses.skinFeatures.isEmpty
            ? nil
            : PDFPaginator.block(
                PDFSkinFeatureView(items: props.diagnoses.skinFeatures).padding(.top, 20)
              )

        // Lead blocks (intro + title + grid) plus the whole table.
        let wholeTable = PDFPaginator.block(tableWhole.padding(.top, 20))
        let leadHeight = intro.height + title.height + grid.height
        if leadHeight + wholeTable.height <= PDFPaginator.contentHeight {
            var result = [intro, title, grid, wholeTable]
            if let skinBlock { result.append(skinBlock) }
            return result
        }

        // Overflow: split the table into a header row block + per-symptom rows.
        var result: [PDFBlock] = [intro, title, grid]
        result.append(PDFPaginator.block(tableHeaderRow.padding(.top, 20)))
        for symptom in props.diagnoses.symptoms {
            result.append(PDFPaginator.block(tableSymptomRow(symptom)))
        }
        if let skinBlock { result.append(skinBlock) }
        return result
    }

    // MARK: - Lead blocks

    private var intro: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(PDFStrings.introTitle)
                    .font(PDFTheme.font(.bold, 13))
                    .foregroundColor(PDFTheme.navy)
                    .lineSpacing(9)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PDFStrings.introText)
                    .font(PDFTheme.font(.regular, 11))
                    .foregroundColor(PDFTheme.navy)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            PDFAssetImage(name: props.isDog ? "dog-illust" : "cat-illust", width: 143, height: 143)
                .padding(.trailing, 4)
        }
        // Kit's `introContainer` has paddingTop 10 only — NO bottom padding.
        // The previous extra bottom 10 pushed the "관찰된 이상징후…" band (and
        // everything after) down by exactly 10pt vs the reference.
        .padding(.top, 10)
    }

    private var sectionTitle: some View {
        PDFSectionTitle(
            title: PDFStrings.summaryTitle(petName: props.petName, part: PDFStrings.partLabel(props.part)),
            imageName: "eyes-illust"
        )
    }

    private var positionsGrid: some View {
        HStack(alignment: .center, spacing: 10) {
            ForEach(props.diagnoses.positions) { position in
                VStack(spacing: 7) {
                    PDFDiagnosisImage(url: position.cropImageUrl, resolved: resolved, size: 90)
                    Text(position.positionName)
                        .font(PDFTheme.font(.bold, 12))
                        .foregroundColor(PDFTheme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Table (whole, when it fits)

    // Column proportions match the kit's flex 2 : 1 : 1 (sign : abnormal : normal).
    private var tableWhole: some View {
        let rowCount = props.diagnoses.symptoms.count + 1 // header + symptom rows
        let height = CGFloat(rowCount) * rowHeight + CGFloat(max(rowCount - 1, 0)) * cellSpacing
        // Fixed page width → split explicitly; layoutPriority does NOT proportion
        // width (the high-priority cell would swallow the check columns).
        return GeometryReader { geo in
            let usable = geo.size.width - cellSpacing * 2
            let signW = usable * 0.5
            let checkW = usable * 0.25
            VStack(spacing: cellSpacing) {
                headerRow(signW: signW, checkW: checkW)
                ForEach(props.diagnoses.symptoms) { symptom in
                    symptomRow(symptom, signW: signW, checkW: checkW)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(height: height)
    }

    // MARK: - Table (split rows, on overflow)

    private var tableHeaderRow: some View {
        GeometryReader { geo in
            let usable = geo.size.width - cellSpacing * 2
            headerRow(signW: usable * 0.5, checkW: usable * 0.25)
        }
        .frame(height: rowHeight)
    }

    private func tableSymptomRow(_ symptom: ScreeningPdfSymptom) -> some View {
        GeometryReader { geo in
            let usable = geo.size.width - cellSpacing * 2
            symptomRow(symptom, signW: usable * 0.5, checkW: usable * 0.25)
        }
        .frame(height: rowHeight)
        .padding(.top, cellSpacing)
    }

    // MARK: - Row builders

    private func headerRow(signW: CGFloat, checkW: CGFloat) -> some View {
        HStack(spacing: cellSpacing) {
            headerCell(PDFStrings.abnormalSignTitle, bg: PDFTheme.slate, width: signW)
            headerCell(PDFStrings.abnormal, bg: PDFTheme.red, width: checkW)
            headerCell(PDFStrings.normal, bg: PDFTheme.blue, width: checkW)
        }
    }

    private func symptomRow(_ symptom: ScreeningPdfSymptom, signW: CGFloat, checkW: CGFloat) -> some View {
        HStack(spacing: cellSpacing) {
            HStack {
                Text(symptom.name)
                    .font(PDFTheme.font(.bold, 13))
                    .foregroundColor(symptom.isAbnormal ? PDFTheme.red : PDFTheme.blue)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .frame(width: signW, height: rowHeight)
            .background(PDFTheme.panel)

            checkCell(show: symptom.isAbnormal, color: PDFTheme.red, width: checkW)
            checkCell(show: !symptom.isAbnormal, color: PDFTheme.blue, width: checkW)
        }
    }

    private func headerCell(_ text: String, bg: Color, width: CGFloat) -> some View {
        Text(text)
            .font(PDFTheme.font(.bold, 13))
            .foregroundColor(.white)
            .frame(width: width, height: rowHeight)
            .background(bg)
    }

    private func checkCell(show: Bool, color: Color, width: CGFloat) -> some View {
        ZStack {
            PDFTheme.panel
            if show { PDFCheckMark(color: color) }
        }
        .frame(width: width, height: rowHeight)
    }
}

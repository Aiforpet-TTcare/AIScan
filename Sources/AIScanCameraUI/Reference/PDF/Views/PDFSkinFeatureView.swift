//
//  PDFSkinFeatureView.swift
//  AIScan
//
//  Skin-feature meters shown under the summary table on SKIN reports. Ports
//  dogtopia_wellness's SwiftUI `SkinFeatureView`: a dark-blue card holding three
//  columns (sensitivity / dryness / roughness), each a horizontal dot meter with
//  the scored dot enlarged and labelled, separated by thin vertical dividers.
//  Eye/tooth reports carry no skin features, so this block is never emitted there.
//

import SwiftUI

struct PDFSkinFeatureView: View {
    let items: [ScreeningPdfSkinFeature]

    private static let board: UInt32 = 0x2B3D6B
    private static let divider: UInt32 = 0x1B2D5B
    private static let dotIdle: UInt32 = 0x5C6FA0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AIScanReferenceStrings.localized(.skinDetails))
                .font(PDFTheme.font(.bold, 12))
                .foregroundColor(.white)

            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    column(item)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 17)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(PDFTheme.color(Self.divider))
                            .frame(width: 1, height: 54)
                            .padding(.horizontal, 10)
                    }
                }
            }
        }
        .padding(.top, 17)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 15).fill(PDFTheme.color(Self.board)))
    }

    /// One feature column: a horizontal dot meter over the feature name.
    private func column(_ item: ScreeningPdfSkinFeature) -> some View {
        let clampedTotal = max(1, item.total)
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(PDFTheme.color(Self.dotIdle).opacity(0.3))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    ForEach(0...clampedTotal, id: \.self) { i in
                        if i == item.value {
                            ZStack {
                                Circle()
                                    .fill(color(for: item.value))
                                    .frame(width: 17, height: 17)
                                Text("\(item.value)")
                                    .font(PDFTheme.font(.bold, 10))
                                    .foregroundColor(.white)
                                    .padding(.bottom, 1)
                            }
                        } else {
                            Circle()
                                .fill(PDFTheme.color(Self.dotIdle))
                                .frame(width: 8, height: 8)
                        }
                        if i < clampedTotal { Spacer(minLength: 0) }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 19)
            }
            Text(item.name)
                .font(PDFTheme.font(.regular, 10))
                .foregroundColor(.white)
                .frame(height: 12)
        }
    }

    private func color(for value: Int) -> Color {
        switch value {
        case 1:  return PDFTheme.color(0x368DF5)
        case 2:  return PDFTheme.color(0xFF970D)
        case 3:  return PDFTheme.color(0xFA535F)
        default: return PDFTheme.color(0x43BA12)
        }
    }
}

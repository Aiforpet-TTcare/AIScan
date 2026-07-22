import SwiftUI
import AIScanCore

@available(iOS 15.0, *)
public struct AIScanResultReferenceView: View {
    @Environment(\.dismiss) private var dismiss

    private let viewModel: AIScanDisplayResultViewModel
    @State private var selectedSymptomID: String?

    public init(viewModel: AIScanDisplayResultViewModel) {
        self.viewModel = viewModel
        _selectedSymptomID = State(initialValue: viewModel.symptoms.first?.id)
    }

    public init(result: AISCDisplayResult) {
        let viewModel = AIScanDisplayResultViewModel(result: result)
        self.viewModel = viewModel
        _selectedSymptomID = State(initialValue: viewModel.symptoms.first?.id)
    }

    public var body: some View {
        VStack(spacing: 0) {
            navigationBar

            ScrollView {
                VStack(spacing: 0) {
                    resultSummary

                    if viewModel.symptoms.isEmpty {
                        emptyResult
                    } else {
                        symptomTabs

                        if let selectedSymptom {
                            symptomCard(selectedSymptom)
                        }
                    }

                    Text(viewModel.notice)
                        .font(.footnote)
                        .foregroundColor(Color(AIScanReferenceTheme.noticeText))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                        .accessibilityIdentifier("aiscan.result.notice")
                }
            }
            .accessibilityIdentifier("aiscan.result.root")
        }
        .background(Color(AIScanReferenceTheme.background).ignoresSafeArea())
    }

    private var navigationBar: some View {
        ZStack {
            Text(viewModel.navigationTitle)
                .font(.headline)
                .foregroundColor(Color(AIScanReferenceTheme.textPrimary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 64)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .light))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(AIScanReferenceTheme.textPrimary))
                .accessibilityLabel(AIScanReferenceStrings.localized(.close))
                .accessibilityIdentifier("aiscan.result.close")

                Spacer()
            }
        }
        .frame(minHeight: 56)
        .padding(.horizontal, 16)
    }

    private var resultSummary: some View {
        VStack(spacing: 0) {
            ZStack {
                AIScanResultStatusBoard(style: viewModel.statusStyle)
                    .frame(width: 212, height: 86)
                    .accessibilityIdentifier("aiscan.result.status-board")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)

            VStack(spacing: 4) {
                Text(viewModel.headline)
                Text(viewModel.subheadline)
            }
            .font(.system(.title2, design: .default).weight(.bold))
            .foregroundColor(Color(AIScanReferenceTheme.textPrimary))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("aiscan.result.status")
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)

            Color.clear.frame(height: 13)

            ZStack {
                if let createdAtText = viewModel.createdAtText, !createdAtText.isEmpty {
                    Text(createdAtText)
                        .font(.system(size: 13))
                        .foregroundColor(Color(AIScanReferenceTheme.dateText))
                        .padding(.horizontal, 15)
                        .frame(height: 34)
                        .background(
                            Color(AIScanReferenceTheme.dateBackground),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(Color(AIScanReferenceTheme.dateBorder), lineWidth: 1)
                        }
                        .accessibilityIdentifier("aiscan.result.date")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)

            Color.clear.frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyResult: some View {
        Text(AIScanReferenceStrings.localized(.noSymptoms))
            .font(.body)
            .foregroundColor(Color(AIScanReferenceTheme.textSecondary))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
            .accessibilityIdentifier("aiscan.result.empty")
    }

    private var selectedSymptom: AIScanDisplaySymptomViewModel? {
        viewModel.symptoms.first { $0.id == selectedSymptomID }
            ?? viewModel.symptoms.first
    }

    private var symptomTabs: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.symptoms) { symptom in
                        let isSelected = symptom.id == selectedSymptom?.id
                        Button {
                            selectedSymptomID = symptom.id
                        } label: {
                            Text(symptom.name ?? symptom.code ?? "-")
                                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                                .foregroundColor(Color(
                                    isSelected
                                        ? AIScanReferenceTheme.selectedChipText
                                        : AIScanReferenceTheme.textSecondary
                                ))
                                .padding(.horizontal, 12)
                                .frame(minWidth: 60, minHeight: 27, maxHeight: 27)
                                .background(
                                    Color(
                                        isSelected
                                            ? AIScanReferenceTheme.selectedChip
                                            : AIScanReferenceTheme.unselectedChipBackground
                                    ),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            isSelected
                                                ? Color.clear
                                                : Color(AIScanReferenceTheme.unselectedChipBorder),
                                            lineWidth: AIScanReferenceTheme.unselectedChipBorderWidth
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("aiscan.result.symptom.\(symptom.id)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .frame(minWidth: max(0, proxy.size.width - 50), alignment: .center)
                .padding(.horizontal, 25)
                .padding(.top, 13)
            }
        }
        .frame(height: 50)
        .accessibilityIdentifier("aiscan.result.symptom-tabs")
    }

    private func symptomCard(_ symptom: AIScanDisplaySymptomViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 25) {
                referenceImage(
                    url: symptom.cropImageURL,
                    caption: AIScanReferenceStrings.localized(.originalPhoto),
                    captionBackground: AIScanReferenceTheme.originalCaptionBackground,
                    captionForeground: AIScanReferenceTheme.originalCaptionText
                )
                referenceImage(
                    url: symptom.heatmapURL,
                    caption: AIScanReferenceStrings.localized(.analysisPhoto),
                    captionBackground: AIScanReferenceTheme.analysisCaptionBackground,
                    captionForeground: AIScanReferenceTheme.analysisCaptionText
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 25)

            Divider()
                .overlay(Color(AIScanReferenceTheme.divider))
                .padding(.horizontal, 25)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(detailSections(for: symptom)) { section in
                    detailSection(section)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .background(
            Color(AIScanReferenceTheme.surfaceSecondary),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 12)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aiscan.result.detail")
    }

    private func detailSections(
        for symptom: AIScanDisplaySymptomViewModel
    ) -> [AIScanDisplayDetailSection] {
        if !symptom.detailSections.isEmpty {
            return symptom.detailSections
        }

        let result = symptom.resultLabel
            ?? "\(AIScanReferenceStrings.localized(.level)) \(symptom.abnormalLevel)"
        return [
            AIScanDisplayDetailSection(
                id: "result-label",
                kind: .symptomDescription,
                title: AIScanReferenceStrings.localized(.symptomDescriptionTitle),
                lines: [result]
            )
        ]
    }

    private func detailSection(_ section: AIScanDisplayDetailSection) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName(for: section.kind))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(AIScanReferenceTheme.sectionIcon))
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(section.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(AIScanReferenceTheme.bodyText))

                ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundColor(Color(AIScanReferenceTheme.bodyText))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aiscan.result.section.\(section.id)")
    }

    private func symbolName(for kind: AIScanDisplayDetailKind) -> String {
        switch kind {
        case .symptomDescription: "message.fill"
        case .relatedConditions: "list.clipboard.fill"
        case .homeCare: "exclamationmark.triangle.fill"
        case .veterinaryCare: "cross.case.fill"
        case .information: "info.circle.fill"
        }
    }

    private func referenceImage(
        url: URL?,
        caption: String,
        captionBackground: UIColor,
        captionForeground: UIColor
    ) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(AIScanReferenceTheme.surface))

                if let url {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(Color(AIScanReferenceTheme.textSecondary))
                }
            }
            .frame(width: 130, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))

            Text(caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(captionForeground))
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(Color(captionBackground), in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 130)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
    }
}

@available(iOS 15.0, *)
private struct AIScanResultStatusBoard: View {
    let style: AIScanDisplayStatusStyle

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let circleSize: CGFloat = 56

            ZStack {
                RoundedRectangle(cornerRadius: size.height * 0.38, style: .continuous)
                    .fill(Color(AIScanReferenceTheme.statusBoardBorder))

                RoundedRectangle(cornerRadius: size.height * 0.31, style: .continuous)
                    .fill(Color(AIScanReferenceTheme.statusBoardBackground))
                    .padding(8)

                HStack(spacing: 7) {
                    statusCircle(.normal, diameter: circleSize)
                    statusCircle(.caution, diameter: circleSize)
                    statusCircle(.warning, diameter: circleSize)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusAccessibilityLabel)
    }

    private func statusCircle(
        _ circleStyle: AIScanDisplayStatusStyle,
        diameter: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color(AIScanReferenceTheme.statusColor(circleStyle)))
                .opacity(style == circleStyle ? 1 : 0.72)

            if style == circleStyle {
                AIScanStatusFace(style: circleStyle)
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(diameter * 0.28)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var statusAccessibilityLabel: String {
        switch style {
        case .normal: AIScanReferenceStrings.localized(.normalHeadline)
        case .caution: AIScanReferenceStrings.localized(.cautionHeadline)
        case .warning: AIScanReferenceStrings.localized(.warningHeadline)
        }
    }
}

@available(iOS 15.0, *)
private struct AIScanStatusFace: Shape {
    let style: AIScanDisplayStatusStyle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let eyeY = rect.minY + rect.height * 0.28
        let eyeHeight = rect.height * 0.18
        for eyeX in [rect.minX + rect.width * 0.28, rect.minX + rect.width * 0.68] {
            path.move(to: CGPoint(x: eyeX, y: eyeY))
            path.addLine(to: CGPoint(x: eyeX, y: eyeY + eyeHeight))
        }

        let mouthY = rect.minY + rect.height * 0.72
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: mouthY))
        switch style {
        case .normal:
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.76, y: mouthY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        case .caution, .warning:
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.76, y: mouthY),
                control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.54)
            )
        }
        return path
    }
}

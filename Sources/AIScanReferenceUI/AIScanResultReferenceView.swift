import SwiftUI
import AIScanCore

@available(iOS 15.0, *)
public struct AIScanResultReferenceView: View {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if viewModel.symptoms.isEmpty {
                    Text(AIScanReferenceStrings.localized(.noSymptoms))
                        .font(.body)
                        .foregroundColor(Color(AIScanReferenceTheme.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .accessibilityIdentifier("aiscan.result.empty")
                } else {
                    symptomTabs

                    if let selectedSymptom {
                        symptomDetail(selectedSymptom)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(AIScanReferenceTheme.background).ignoresSafeArea())
        .accessibilityIdentifier("aiscan.result.root")
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(viewModel.status)
                .font(.title2.weight(.semibold))
                .foregroundColor(Color(AIScanReferenceTheme.textPrimary))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("aiscan.result.status")

            if let diagnosisID = viewModel.diagnosisID, !diagnosisID.isEmpty {
                Text(diagnosisID)
                    .font(.footnote)
                    .foregroundColor(Color(AIScanReferenceTheme.textSecondary))
                    .accessibilityIdentifier("aiscan.result.diagnosis-id")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedSymptom: AIScanDisplaySymptomViewModel? {
        viewModel.symptoms.first { $0.id == selectedSymptomID }
            ?? viewModel.symptoms.first
    }

    private var symptomTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.symptoms) { symptom in
                    let isSelected = symptom.id == selectedSymptom?.id
                    Button {
                        selectedSymptomID = symptom.id
                    } label: {
                        Text(symptom.name ?? symptom.code ?? "-")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color(
                                isSelected
                                    ? AIScanReferenceTheme.selectedChipText
                                    : AIScanReferenceTheme.textSecondary
                            ))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
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
        }
        .accessibilityIdentifier("aiscan.result.symptom-tabs")
    }

    private func symptomDetail(_ symptom: AIScanDisplaySymptomViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
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

            Divider()
                .overlay(Color(AIScanReferenceTheme.divider))

            VStack(alignment: .leading, spacing: 8) {
                Text(symptom.name ?? symptom.code ?? "-")
                    .font(.headline)
                    .foregroundColor(Color(AIScanReferenceTheme.textPrimary))
                Text(symptom.resultLabel ?? "\(AIScanReferenceStrings.localized(.level)) \(symptom.abnormalLevel)")
                    .font(.body)
                    .foregroundColor(Color(AIScanReferenceTheme.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(
            Color(AIScanReferenceTheme.surfaceSecondary),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aiscan.result.detail")
    }

    private func referenceImage(
        url: URL?,
        caption: String,
        captionBackground: UIColor,
        captionForeground: UIColor
    ) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(captionForeground))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(captionBackground), in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
    }
}

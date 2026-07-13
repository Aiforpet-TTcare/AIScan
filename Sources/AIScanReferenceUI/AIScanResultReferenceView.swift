import SwiftUI
import AIScanCore

@available(iOS 15.0, *)
public struct AIScanResultReferenceView: View {
    private let viewModel: AIScanDisplayResultViewModel

    public init(viewModel: AIScanDisplayResultViewModel) {
        self.viewModel = viewModel
    }

    public init(result: AISCDisplayResult) {
        self.viewModel = AIScanDisplayResultViewModel(result: result)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(viewModel.symptoms) { symptom in
                    symptomRow(symptom)
                }
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.status)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            if let diagnosisID = viewModel.diagnosisID, !diagnosisID.isEmpty {
                Text(diagnosisID)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func symptomRow(_ symptom: AIScanDisplaySymptomViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(symptom.name ?? symptom.code ?? "-")
                        .font(.headline)
                    Text(symptom.resultLabel ?? "level \(symptom.abnormalLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text("\(symptom.abnormalLevel)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(spacing: 12) {
                referenceImage(url: symptom.cropImageURL)
                referenceImage(url: symptom.heatmapURL)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func referenceImage(url: URL?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))

            if let url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

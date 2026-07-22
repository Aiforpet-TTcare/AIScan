import Foundation
import AIScanCore

public struct AIScanDisplaySymptomViewModel: Identifiable, Equatable {
    public let id: String
    public let code: String?
    public let name: String?
    public let heatmapURL: URL?
    public let cropImageURL: URL?
    public let abnormalLevel: Int
    public let resultLabel: String?

    public init(
        id: String? = nil,
        code: String? = nil,
        name: String? = nil,
        heatmapURL: URL? = nil,
        cropImageURL: URL? = nil,
        abnormalLevel: Int = 0,
        resultLabel: String? = nil
    ) {
        self.code = code
        self.name = name
        self.heatmapURL = heatmapURL
        self.cropImageURL = cropImageURL
        self.abnormalLevel = abnormalLevel
        self.resultLabel = resultLabel
        self.id = id ?? [
            code,
            name,
            String(abnormalLevel),
            resultLabel
        ]
        .compactMap { $0 }
        .joined(separator: "|")
    }

    public init(symptom: AISCDisplaySymptom) {
        self.init(
            code: symptom.code,
            name: symptom.name,
            heatmapURL: symptom.heatmapURL,
            cropImageURL: symptom.cropImageURL,
            abnormalLevel: symptom.abnormalLevel,
            resultLabel: symptom.resultLabel
        )
    }
}

public struct AIScanDisplayResultViewModel: Equatable {
    public let status: String
    public let diagnosisID: String?
    public let symptoms: [AIScanDisplaySymptomViewModel]

    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanDisplaySymptomViewModel] = []
    ) {
        self.status = status
        self.diagnosisID = diagnosisID
        self.symptoms = symptoms
    }

    public init(result: AISCDisplayResult) {
        self.init(
            status: result.status,
            diagnosisID: result.diagnosisID,
            symptoms: result.symptoms.map(AIScanDisplaySymptomViewModel.init)
        )
    }
}

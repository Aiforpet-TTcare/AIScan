import Foundation
import AIScanCore

public enum AIScanDisplayStatus: String, Equatable, Sendable {
    case normal = "NORMAL"
    case caution = "CAUTION"
    case warning = "WARNING"

    init(rawStatus: String) {
        self = Self(rawValue: rawStatus.uppercased()) ?? .caution
    }
}

/// One already-approved, display-only row rendered under a result image.
/// The UI never derives this content from model identifiers, predictions, or thresholds.
public struct AIScanDisplayDetailRowViewModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let iconName: String?

    public init(id: String? = nil, text: String, iconName: String? = nil) {
        self.id = id ?? "\(iconName ?? "row")|\(text)"
        self.text = text
        self.iconName = iconName
    }
}

public struct AIScanDisplaySymptomViewModel: Identifiable, Equatable {
    public let id: String
    public let code: String?
    public let name: String?
    public let heatmapURL: URL?
    public let cropImageURL: URL?
    public let abnormalLevel: Int
    public let resultLabel: String?
    public let detailRows: [AIScanDisplayDetailRowViewModel]

    public init(
        id: String? = nil,
        code: String? = nil,
        name: String? = nil,
        heatmapURL: URL? = nil,
        cropImageURL: URL? = nil,
        abnormalLevel: Int = 0,
        resultLabel: String? = nil,
        detailRows: [AIScanDisplayDetailRowViewModel] = []
    ) {
        self.code = code
        self.name = name
        self.heatmapURL = heatmapURL
        self.cropImageURL = cropImageURL
        self.abnormalLevel = abnormalLevel
        self.resultLabel = resultLabel
        self.detailRows = detailRows
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
    public let headline: String?
    public let subtitle: String?
    public let analyzedAt: Date
    public let notice: String?

    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanDisplaySymptomViewModel] = [],
        headline: String? = nil,
        subtitle: String? = nil,
        analyzedAt: Date = Date(),
        notice: String? = nil
    ) {
        self.status = status
        self.diagnosisID = diagnosisID
        self.symptoms = symptoms
        self.headline = headline
        self.subtitle = subtitle
        self.analyzedAt = analyzedAt
        self.notice = notice
    }

    public init(result: AISCDisplayResult) {
        self.init(
            status: result.status,
            diagnosisID: result.diagnosisID,
            symptoms: result.symptoms.map(AIScanDisplaySymptomViewModel.init)
        )
    }

    public var displayStatus: AIScanDisplayStatus {
        AIScanDisplayStatus(rawStatus: status)
    }
}

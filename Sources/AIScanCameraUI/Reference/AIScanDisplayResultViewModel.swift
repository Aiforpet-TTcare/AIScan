import Foundation
import AIScanCore

public enum AIScanDisplayStatus: String, Equatable, Sendable {
    case normal = "NORMAL"
    case caution = "CAUTION"
    case cautionQuestionnaire = "CAUTION_Q"
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

    public init(detail: AISCDisplayDetail) {
        let body = detail.contents.joined(separator: "<br>")
        let text: String
        if let title = detail.title, !title.isEmpty {
            text = body.isEmpty ? "<b>\(title)</b>" : "<b>\(title)</b><br>\(body)"
        } else {
            text = body
        }
        self.init(id: detail.key, text: text)
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
        let rows = symptom.details.map(AIScanDisplayDetailRowViewModel.init(detail:))
        self.init(
            code: symptom.code,
            name: symptom.name,
            heatmapURL: symptom.heatmapURL,
            cropImageURL: symptom.cropImageURL,
            abnormalLevel: symptom.abnormalLevel,
            resultLabel: symptom.resultLabel,
            detailRows: rows
        )
    }
}

/// Display-only skin condition meters. Core owns their derivation; the UI only
/// renders these bounded values.
public struct AIScanDisplaySkinFeaturesViewModel: Equatable, Sendable {
    public let sensitivity: Int
    public let dryness: Int
    public let roughness: Int
    public let total: Int

    public init(sensitivity: Int, dryness: Int, roughness: Int, total: Int = 3) {
        let boundedTotal = max(1, total)
        self.total = boundedTotal
        self.sensitivity = min(max(0, sensitivity), boundedTotal)
        self.dryness = min(max(0, dryness), boundedTotal)
        self.roughness = min(max(0, roughness), boundedTotal)
    }

    public init(features: AISCDisplaySkinFeatures) {
        self.init(
            sensitivity: features.sensitivity,
            dryness: features.dryness,
            roughness: features.roughness,
            total: features.total
        )
    }
}

public struct AIScanDisplayResultViewModel: Equatable {
    public let status: String
    public let diagnosisID: String?
    /// Abnormal-only collection rendered as the existing result tabs.
    public let symptoms: [AIScanDisplaySymptomViewModel]
    /// Complete normal + abnormal collection used by the report.
    public let analyzedSymptoms: [AIScanDisplaySymptomViewModel]
    /// Original common result rows selected by Core from the private catalog.
    public let resultDetails: [AIScanDisplayDetailRowViewModel]
    public let skinFeatures: AIScanDisplaySkinFeaturesViewModel?
    public let headline: String?
    public let subtitle: String?
    public let analyzedAt: Date
    public let notice: String?

    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanDisplaySymptomViewModel] = [],
        analyzedSymptoms: [AIScanDisplaySymptomViewModel]? = nil,
        resultDetails: [AIScanDisplayDetailRowViewModel] = [],
        skinFeatures: AIScanDisplaySkinFeaturesViewModel? = nil,
        headline: String? = nil,
        subtitle: String? = nil,
        analyzedAt: Date = Date(),
        notice: String? = nil
    ) {
        self.status = status
        self.diagnosisID = diagnosisID
        self.symptoms = symptoms
        self.analyzedSymptoms = analyzedSymptoms ?? symptoms
        self.resultDetails = resultDetails
        self.skinFeatures = skinFeatures
        self.headline = headline
        self.subtitle = subtitle
        self.analyzedAt = analyzedAt
        self.notice = notice
    }

    public init(result: AISCDisplayResult) {
        let symptoms = result.symptoms.map(AIScanDisplaySymptomViewModel.init)
        self.init(
            status: result.status,
            diagnosisID: result.diagnosisID,
            symptoms: symptoms,
            analyzedSymptoms: result.analyzedSymptoms.map(AIScanDisplaySymptomViewModel.init),
            resultDetails: result.resultDetails.map(AIScanDisplayDetailRowViewModel.init(detail:)),
            skinFeatures: result.skinFeatures.map(AIScanDisplaySkinFeaturesViewModel.init(features:)),
            analyzedAt: result.analyzedAt
        )
    }

    public var displayStatus: AIScanDisplayStatus {
        AIScanDisplayStatus(rawStatus: status)
    }

    /// Localized title used by the original on-device customer JSON contract.
    /// Newlines belong to the visual result screen, not the callback payload.
    public var legacyCallbackTitle: String {
        let value = switch displayStatus {
        case .normal: AIScanReferenceStrings.localized(.normalHeadline)
        case .caution: AIScanReferenceStrings.localized(.cautionHeadline)
        case .cautionQuestionnaire:
            AIScanReferenceStrings.localized(.cautionQuestionnaireHeadline)
        case .warning: AIScanReferenceStrings.localized(.warningHeadline)
        }
        return value.replacingOccurrences(of: "\n", with: " ")
    }

    /// Original CAUTION_Q description returned to existing host applications.
    public var legacyQuestionnaireDescription: String {
        AIScanReferenceStrings.localized(.cautionQuestionnaireDescription)
    }
}

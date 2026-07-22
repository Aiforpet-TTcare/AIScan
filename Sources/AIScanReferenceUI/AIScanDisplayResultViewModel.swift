import Foundation
import AIScanCore

public enum AIScanDisplayStatusStyle: String, Equatable, Sendable {
    case normal
    case caution
    case warning

    init(status: String) {
        switch status.uppercased() {
        case "WARNING", "ABNORMAL", "DANGER":
            self = .warning
        case "CAUTION", "CAUTION_Q", "ATTENTION", "OBSERVE":
            self = .caution
        default:
            self = .normal
        }
    }
}

public enum AIScanDisplayDetailKind: String, Equatable, Sendable {
    case symptomDescription
    case relatedConditions
    case homeCare
    case veterinaryCare
    case information
}

/// Host- or Core-supplied presentation copy that is safe to render publicly.
///
/// It deliberately carries no scores, thresholds, model identifiers, raw
/// predictions, or transport fields.
public struct AIScanDisplayDetailSection: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: AIScanDisplayDetailKind
    public let title: String
    public let lines: [String]

    public init(
        id: String,
        kind: AIScanDisplayDetailKind = .information,
        title: String,
        lines: [String]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.lines = lines
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
    public let detailSections: [AIScanDisplayDetailSection]

    public init(
        id: String? = nil,
        code: String? = nil,
        name: String? = nil,
        heatmapURL: URL? = nil,
        cropImageURL: URL? = nil,
        abnormalLevel: Int = 0,
        resultLabel: String? = nil,
        detailSections: [AIScanDisplayDetailSection] = []
    ) {
        self.code = code
        self.name = name
        self.heatmapURL = heatmapURL
        self.cropImageURL = cropImageURL
        self.abnormalLevel = abnormalLevel
        self.resultLabel = resultLabel
        self.detailSections = detailSections
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
    public let statusStyle: AIScanDisplayStatusStyle
    public let navigationTitle: String
    public let headline: String
    public let subheadline: String
    public let createdAtText: String?
    public let notice: String

    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanDisplaySymptomViewModel] = [],
        statusStyle: AIScanDisplayStatusStyle? = nil,
        navigationTitle: String? = nil,
        headline: String? = nil,
        subheadline: String? = nil,
        createdAtText: String? = nil,
        notice: String? = nil
    ) {
        self.status = status
        self.diagnosisID = diagnosisID
        self.symptoms = symptoms
        let resolvedStyle = statusStyle ?? AIScanDisplayStatusStyle(status: status)
        self.statusStyle = resolvedStyle
        self.navigationTitle = navigationTitle
            ?? AIScanReferenceStrings.localized(.navigationTitle)
        self.headline = headline
            ?? AIScanReferenceStrings.localized(resolvedStyle.defaultHeadlineKey)
        self.subheadline = subheadline
            ?? AIScanReferenceStrings.localized(resolvedStyle.defaultSubheadlineKey)
        self.createdAtText = createdAtText
        self.notice = notice ?? AIScanReferenceStrings.localized(.notice)
    }

    public init(result: AISCDisplayResult) {
        self.init(
            status: result.status,
            diagnosisID: result.diagnosisID,
            symptoms: result.symptoms.map(AIScanDisplaySymptomViewModel.init),
            createdAtText: Self.currentTimestamp()
        )
    }

    private static func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd HH:mm"
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        return formatter.string(from: Date())
    }
}

private extension AIScanDisplayStatusStyle {
    var defaultHeadlineKey: AIScanReferenceStringKey {
        switch self {
        case .normal: .normalHeadline
        case .caution: .cautionHeadline
        case .warning: .warningHeadline
        }
    }

    var defaultSubheadlineKey: AIScanReferenceStringKey {
        switch self {
        case .normal: .normalSubheadline
        case .caution: .cautionSubheadline
        case .warning: .warningSubheadline
        }
    }
}

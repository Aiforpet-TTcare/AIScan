import Foundation
import AIScanCore

/// Display-safe symptom information returned by the high-level scan facade.
///
/// This type intentionally contains no model identifiers, raw predictions,
/// thresholds, tensors, or transport payloads.
public struct AIScanSymptom: Equatable, Sendable {
    public let code: String?
    public let name: String?
    public let heatmapURL: URL?
    public let cropImageURL: URL?
    public let abnormalLevel: Int
    public let resultLabel: String?

    public init(
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
    }

    public init(displaySymptom: AISCDisplaySymptom) {
        self.init(
            code: displaySymptom.code,
            name: displaySymptom.name,
            heatmapURL: displaySymptom.heatmapURL,
            cropImageURL: displaySymptom.cropImageURL,
            abnormalLevel: displaySymptom.abnormalLevel,
            resultLabel: displaySymptom.resultLabel
        )
    }
}

/// Display-safe result returned by `AIScanManager`.
public struct AIScanResult: Equatable, Sendable {
    public let status: String
    public let diagnosisID: String?
    public let symptoms: [AIScanSymptom]

    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanSymptom] = []
    ) {
        self.status = status
        self.diagnosisID = diagnosisID
        self.symptoms = symptoms
    }

    public init(displayResult: AISCDisplayResult) {
        self.init(
            status: displayResult.status,
            diagnosisID: displayResult.diagnosisID,
            symptoms: displayResult.symptoms.map(AIScanSymptom.init(displaySymptom:))
        )
    }
}

/// Optional host-owned result controller used by `AIScanManager.showCamera`.
///
/// The manager calls this method on the main actor before presenting the
/// controller. Only the display-safe `AIScanResult` crosses this boundary.
@MainActor
public protocol AIScanResultViewControlling: AnyObject {
    func apply(result: AIScanResult)
}

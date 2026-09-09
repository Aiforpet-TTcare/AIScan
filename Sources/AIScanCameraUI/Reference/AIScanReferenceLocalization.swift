import Foundation

enum AIScanReferenceStringKey: String {
    case resultTitle = "result.title"
    case normalHeadline = "result.status.normal"
    case cautionHeadline = "result.status.caution"
    case cautionQuestionnaireHeadline = "result.status.caution_questionnaire"
    case cautionQuestionnaireDescription = "result.status.caution_questionnaire_description"
    case warningHeadline = "result.status.warning"
    case originalPhoto = "result.original_photo"
    case analysisPhoto = "result.analysis_photo"
    case noSymptoms = "result.no_symptoms"
    case level = "result.level"
    case notice = "result.notice"
    case skinDetails = "result.skin_details"
    case skinSensitivity = "result.skin_sensitivity"
    case skinDryness = "result.skin_dryness"
    case skinRoughness = "result.skin_roughness"
    case exportReport = "pdf.export_button"
    case close = "common.close"
}

enum AIScanReferenceStrings {
    static func localized(
        _ key: AIScanReferenceStringKey,
        languageCode: String? = nil
    ) -> String {
        let bundle = localizedBundle(languageCode: languageCode)
        return NSLocalizedString(
            key.rawValue,
            tableName: "Localizable",
            bundle: bundle,
            value: fallback(for: key),
            comment: ""
        )
    }

    private static func localizedBundle(languageCode: String?) -> Bundle {
        guard let languageCode,
              let path = resourceBundle.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return resourceBundle
        }
        return bundle
    }

    static var resourceBundle: Bundle {
#if SWIFT_PACKAGE
        Bundle.module
#else
        let containingBundle = Bundle(for: AIScanReferenceBundleToken.self)
        let candidates = [containingBundle, .main]
        for candidate in candidates {
            if let url = candidate.url(
                forResource: "AIScanReferenceUIResources",
                withExtension: "bundle"
            ), let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return containingBundle
#endif
    }

    private static func fallback(for key: AIScanReferenceStringKey) -> String {
        switch key {
        case .resultTitle:
            "AI Health Check Result"
        case .normalHeadline:
            "No Concerning Signs\nat This Time"
        case .cautionHeadline:
            "Monitor Closely"
        case .cautionQuestionnaireHeadline:
            "Please monitor closely."
        case .cautionQuestionnaireDescription:
            "The image looks normal, but based on the questionnaire, your pet may still be feeling discomfort or pain that isn't visible in photos. Please keep a close eye and consider a veterinary visit if needed."
        case .warningHeadline:
            "Seek Veterinary Care\nas Soon as Possible"
        case .originalPhoto:
            "Original Photo"
        case .analysisPhoto:
            "AI Analysis"
        case .noSymptoms:
            "No symptoms to display"
        case .level:
            "Level"
        case .notice:
            "This service uses AI to detect signs of illness and provide alerts. For an accurate diagnosis, we recommend consulting a veterinarian."
        case .skinDetails:
            "Skin Condition Details"
        case .skinSensitivity:
            "Sensitivity"
        case .skinDryness:
            "Dryness"
        case .skinRoughness:
            "Roughness"
        case .exportReport:
            "Share PDF report"
        case .close:
            "Close"
        }
    }
}

private final class AIScanReferenceBundleToken {}

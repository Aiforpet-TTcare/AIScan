import Foundation

enum AIScanReferenceStringKey: String {
    case navigationTitle = "result.navigation_title"
    case originalPhoto = "result.original_photo"
    case analysisPhoto = "result.analysis_photo"
    case noSymptoms = "result.no_symptoms"
    case level = "result.level"
    case normalHeadline = "result.normal.headline"
    case normalSubheadline = "result.normal.subheadline"
    case cautionHeadline = "result.caution.headline"
    case cautionSubheadline = "result.caution.subheadline"
    case warningHeadline = "result.warning.headline"
    case warningSubheadline = "result.warning.subheadline"
    case symptomDescriptionTitle = "result.section.symptom_description"
    case relatedConditionsTitle = "result.section.related_conditions"
    case homeCareTitle = "result.section.home_care"
    case veterinaryCareTitle = "result.section.veterinary_care"
    case notice = "result.notice"
    case close = "result.close"
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

    private static var resourceBundle: Bundle {
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
        case .navigationTitle:
            "AI Health Check Result"
        case .originalPhoto:
            "Original photo"
        case .analysisPhoto:
            "AI analysis image"
        case .noSymptoms:
            "No symptoms to display"
        case .level:
            "Level"
        case .normalHeadline:
            "No concerning signs"
        case .normalSubheadline:
            "Keep up regular observation"
        case .cautionHeadline:
            "Signs were detected"
        case .cautionSubheadline:
            "Close observation is recommended"
        case .warningHeadline:
            "Signs were detected"
        case .warningSubheadline:
            "Please seek veterinary care"
        case .symptomDescriptionTitle:
            "What is this sign?"
        case .relatedConditionsTitle:
            "Related conditions and causes"
        case .homeCareTitle:
            "Home-care guidance"
        case .veterinaryCareTitle:
            "When to see a veterinarian"
        case .notice:
            "This service uses AI to detect signs of illness and provide alerts. For an accurate diagnosis, consult a veterinarian."
        case .close:
            "Close"
        }
    }
}

private final class AIScanReferenceBundleToken {}

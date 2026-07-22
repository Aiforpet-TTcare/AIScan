import Foundation

enum AIScanReferenceStringKey: String {
    case resultTitle = "result.title"
    case normalHeadline = "result.status.normal"
    case cautionHeadline = "result.status.caution"
    case warningHeadline = "result.status.warning"
    case originalPhoto = "result.original_photo"
    case analysisPhoto = "result.analysis_photo"
    case noSymptoms = "result.no_symptoms"
    case level = "result.level"
    case notice = "result.notice"
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
        case .close:
            "Close"
        }
    }
}

private final class AIScanReferenceBundleToken {}

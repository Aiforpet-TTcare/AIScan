import Foundation

enum AIScanReferenceStringKey: String {
    case originalPhoto = "result.original_photo"
    case analysisPhoto = "result.analysis_photo"
    case noSymptoms = "result.no_symptoms"
    case level = "result.level"
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
        case .originalPhoto:
            "Original photo"
        case .analysisPhoto:
            "AI analysis image"
        case .noSymptoms:
            "No symptoms to display"
        case .level:
            "Level"
        }
    }
}

private final class AIScanReferenceBundleToken {}

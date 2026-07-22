import Foundation

enum AIScanCameraStringKey: String {
    case preparing = "camera.preparing"
    case scanning = "camera.scanning"
    case ready = "camera.ready"
    case analyzing = "camera.analyzing"
    case complete = "camera.complete"
    case capture = "camera.capture"
    case close = "camera.close"
    case retry = "camera.retry"
    case permissionDenied = "camera.permission_denied"
}

enum AIScanCameraStrings {
    static func localized(
        _ key: AIScanCameraStringKey,
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
        let containingBundle = Bundle(for: AIScanCameraBundleToken.self)
        let candidates = [containingBundle, .main]
        for candidate in candidates {
            if let url = candidate.url(
                forResource: "AIScanCameraUIResources",
                withExtension: "bundle"
            ), let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return containingBundle
#endif
    }

    private static func fallback(for key: AIScanCameraStringKey) -> String {
        switch key {
        case .preparing:
            "Preparing…"
        case .scanning:
            "Scanning…"
        case .ready:
            "Ready"
        case .analyzing:
            "Analyzing…"
        case .complete:
            "Complete"
        case .capture:
            "Capture"
        case .close:
            "Close"
        case .retry:
            "Retry"
        case .permissionDenied:
            "Camera permission is required to start a scan."
        }
    }
}

private final class AIScanCameraBundleToken {}

import Foundation
import AIScanCore

enum AIScanCameraStringKey: String {
    case preparing = "camera.preparing"
    case scanning = "camera.scanning"
    case ready = "camera.ready"
    case analyzing = "camera.analyzing"
    case complete = "camera.complete"
    case capture = "camera.capture"
    case flash = "camera.flash"
    case album = "camera.album"
    case close = "camera.close"
    case retry = "camera.retry"
    case start = "camera.start"
    case flashRecommendationTitle = "camera.flash_recommendation.title"
    case flashRecommendationAction = "camera.flash_recommendation.action"
    case flashRecommendationActionAccent = "camera.flash_recommendation.action_accent"
    case flashRecommendationBody = "camera.flash_recommendation.body"
    case permissionDenied = "camera.permission_denied"
    case unavailable = "camera.unavailable"
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

    static func displayMessage(for error: Error) -> String {
        if let cameraError = error as? AIScanCameraViewControllerError {
            switch cameraError {
            case .cameraPermissionDenied:
                return localized(.permissionDenied)
            }
        }

        let approvedReason = (error as NSError).userInfo[AISCDisplayReasonKey] as? String
        if let approvedReason, !approvedReason.isEmpty {
            return approvedReason
        }
        return localized(.unavailable)
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
        case .flash:
            "Flash"
        case .album:
            "Photo library"
        case .close:
            "Close"
        case .retry:
            "Retry"
        case .start:
            "Start"
        case .flashRecommendationTitle:
            "We recommend using flash"
        case .flashRecommendationAction:
            "Use flash for better\nresults."
        case .flashRecommendationActionAccent:
            "Use flash"
        case .flashRecommendationBody:
            "Sudden use of flash can startle your pet. There is no scientific evidence that it harms them, but to avoid a glare you can cover the flash with a piece of paper."
        case .permissionDenied:
            "Camera permission is required to start a scan."
        case .unavailable:
            "Camera is unavailable. Please try again."
        }
    }
}

private final class AIScanCameraBundleToken {}

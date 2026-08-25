import Foundation
import AIScanCore

enum AIScanCameraStringKey: String {
    case preparing = "camera.preparing"
    case scanning = "camera.scanning"
    case ready = "camera.ready"
    case analyzing = "camera.analyzing"
    case complete = "camera.complete"
    case capture = "camera.capture"
    case close = "camera.close"
    case retry = "camera.retry"
    case settings = "camera.settings"
    case permissionDenied = "camera.permission_denied"
    case unavailable = "camera.unavailable"
    case startPrompt = "camera.start_prompt"
    case notice = "popup.notice"
    case confirm = "popup.confirm"
    case flashTitle = "popup.flash.title"
    case flashSubtitle = "popup.flash.subtitle"
    case flashBenefit = "popup.flash.benefit"
    case skinDistance = "popup.flash.skin_distance"
    case start = "popup.start"
    case timeoverTitle = "popup.timeover.title"
    case timeoverSubtitle = "popup.timeover.subtitle"
    case timeoverRetry = "popup.timeover.retry"
    case guide = "popup.timeover.guide"
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
            return localizedMessageKey(approvedReason)
        }
        return localized(.unavailable)
    }

    static func localizedMessageKey(_ key: String, languageCode: String? = nil) -> String {
        NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: localizedBundle(languageCode: languageCode),
            value: key,
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
        case .settings:
            "Open Settings"
        case .permissionDenied:
            "Camera permission is required to start a scan."
        case .unavailable:
            "Camera is unavailable. Please try again."
        case .startPrompt:
            "Press the button to start AI Scan."
        case .notice:
            "Notice"
        case .confirm:
            "OK"
        case .flashTitle:
            "We recommend using flash"
        case .flashSubtitle:
            "Sudden use of flash can startle your pet. There is no scientific evidence that it harms them, but to avoid glare you can cover the flash with a piece of paper."
        case .flashBenefit:
            "Use flash for better results."
        case .skinDistance:
            "Keep as much fur out of frame as possible and capture at least 10 cm from the skin."
        case .start:
            "Start"
        case .timeoverTitle:
            "Time’s up."
        case .timeoverSubtitle:
            "Having trouble capturing the image?\nPlease refer to the detailed user guide."
        case .timeoverRetry:
            "Try again"
        case .guide:
            "User guide"
        }
    }
}

private final class AIScanCameraBundleToken {}

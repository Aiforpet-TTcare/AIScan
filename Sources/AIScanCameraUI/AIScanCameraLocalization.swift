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
    case criticalError = "camera.critical_error"
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
    case retakeTitle = "popup.retake.title"
    case retakeWrong = "popup.retake.wrong"
    case retakeRight = "popup.retake.right"
    case retakeAction = "popup.retake.action"
}

enum AIScanCameraStrings {
    /// The localization currently selected by the SDK resource bundle.
    /// UI-only visibility rules must follow this value instead of the device
    /// locale so a host app's per-app language override remains consistent.
    static var currentLanguageCode: String {
        resourceBundle.preferredLocalizations
            .first { $0.caseInsensitiveCompare("Base") != .orderedSame }?
            .lowercased() ?? "en"
    }

    static func isKoreanUI(languageCode: String? = nil) -> Bool {
        (languageCode ?? currentLanguageCode).lowercased().hasPrefix("ko")
    }

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

    static func displayMessage(for error: Error, languageCode: String? = nil) -> String {
        if let cameraError = error as? AIScanCameraViewControllerError {
            switch cameraError {
            case .cameraPermissionDenied:
                return localized(.permissionDenied, languageCode: languageCode)
            }
        }

        let nsError = error as NSError
        if nsError.domain == AISCErrorDomain {
            if nsError.code == AISCErrorCode.frameRejected.rawValue,
               let approvedReason = nsError.userInfo[AISCDisplayReasonKey] as? String,
               !approvedReason.isEmpty {
                return localizedMessageKey(
                    canonicalGuidanceKey(approvedReason),
                    languageCode: languageCode
                )
            }
            return appendingCoreErrorCode(
                localized(.criticalError, languageCode: languageCode),
                error: error
            )
        }

        let approvedReason = nsError.userInfo[AISCDisplayReasonKey] as? String
        if let approvedReason, !approvedReason.isEmpty {
            return localizedMessageKey(approvedReason, languageCode: languageCode)
        }
        return localized(.unavailable, languageCode: languageCode)
    }

    static func albumDisplayMessage(
        for error: Error,
        partType: AISCPartType,
        analysisPosition: String?,
        languageCode: String? = nil
    ) -> String {
        let nsError = error as NSError
        guard nsError.domain == AISCErrorDomain,
              let reason = nsError.userInfo[AISCDisplayReasonKey] as? String,
              !reason.isEmpty else {
            return displayMessage(for: error, languageCode: languageCode)
        }

        let key: String?
        switch reason {
        case "눈을 촬영해 주세요.":
            key = "눈이 잘 보이는 사진을 선택해 주세요."
        case "치아를 촬영해 주세요.":
            key = "치아가 잘 보이는 사진을 선택해 주세요."
        case "초점을 잘 맞춰 주세요.", "hold_still":
            key = "초점이 잘 맞는 선명한 사진을 선택해 주세요."
        case "더 가까이에서 촬영해 주세요", "move_closer":
            key = "피사체가 더 크게 나온 사진을 선택해 주세요."
        case "더 멀리서 촬영해 주세요", "move_farther":
            key = "피사체가 눈에 다 들어오는 사진을 선택해 주세요."
        case "귀를 촬영해 주세요.", "몸통을 촬영해 주세요.",
             "발을 촬영해 주세요.", "피부를 촬영해 주세요.":
            key = albumSkinSelectionKey(
                partType: partType,
                analysisPosition: analysisPosition
            )
        case "해상도가 너무 낮습니다. 더 선명한 사진으로 시도해 주세요.":
            key = reason
        default:
            key = nil
        }

        guard let key else {
            return displayMessage(for: error, languageCode: languageCode)
        }
        return localizedMessageKey(key, languageCode: languageCode)
    }

    private static func albumSkinSelectionKey(
        partType: AISCPartType,
        analysisPosition: String?
    ) -> String {
        guard partType == .skin else {
            return "피부가 잘 보이는 사진을 선택해 주세요."
        }
        switch analysisPosition?.lowercased() {
        case "ear":
            return "귀가 잘 보이는 사진을 선택해 주세요."
        case "belly", "body":
            return "몸통이 잘 보이는 사진을 선택해 주세요."
        case "foot", "paw", "paws":
            return "발이 잘 보이는 사진을 선택해 주세요."
        default:
            return "피부가 잘 보이는 사진을 선택해 주세요."
        }
    }

    private static func canonicalGuidanceKey(_ reason: String) -> String {
        switch reason {
        case "더 가까이에서 촬영해 주세요":
            "move_closer"
        case "더 멀리서 촬영해 주세요":
            "move_farther"
        case "초점을 잘 맞춰 주세요.":
            "hold_still"
        default:
            reason
        }
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

    private static func appendingCoreErrorCode(_ message: String, error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AISCErrorDomain else { return message }
        return "\(message)\n[AISC-\(nsError.code)]"
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
        case .criticalError:
            "A temporary error occurred. Please try again."
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
        case .retakeTitle:
            "The captured image is difficult to analyze"
        case .retakeWrong:
            "Avoid this"
        case .retakeRight:
            "Capture like this"
        case .retakeAction:
            "Would you like to try again?"
        }
    }
}

private final class AIScanCameraBundleToken {}

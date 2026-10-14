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
        if error is AIScanMultiPhotoError { return localizedMessageKey("multi.requires_ttapi", languageCode: languageCode) }
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
                let guidance = localizedBundle(languageCode: languageCode).localizedString(
                    forKey: canonicalGuidanceKey(approvedReason),
                    value: "__AISC_GUIDANCE_MISSING__", table: "Localizable"
                )
                if guidance != "__AISC_GUIDANCE_MISSING__" { return guidance }
            }
            return localizedMessageKey(coreErrorMessageKey(nsError.code), languageCode: languageCode)
        }

        // Keep unexpected provider text and diagnostics out of user-facing UI.
        return localized(.unavailable, languageCode: languageCode)
    }

    static func albumQualityFailureMessage(
        for report: AIScanAlbumQualityReport,
        isInspecting: Bool,
        analysisPosition: String?,
        languageCode: String? = nil
    ) -> String? {
        let key: String
        if report.originalRows.contains(where: { $0.issue == "resolution" }) {
            key = "해상도가 너무 낮습니다. 더 선명한 사진으로 시도해 주세요."
        } else if !report.originalIsValid {
            key = report.metadata.bitsPerPixel == nil ? "album.quality.unknown" : "photo.color_quality"
        } else if isInspecting || report.isValid {
            return nil
        } else if let error = report.inspectionError {
            return albumDisplayMessage(for: error, partType: report.part,
                analysisPosition: analysisPosition, languageCode: languageCode)
        } else if report.detectedSize != nil && report.detectionIssue == nil {
            key = albumFramingKey(partType: report.part, larger: true)
        } else {
            switch report.part {
            case .eye: key = "눈이 잘 보이는 사진을 선택해 주세요."
            case .teeth: key = "치아가 잘 보이는 사진을 선택해 주세요."
            default: key = albumSkinSelectionKey(partType: report.part, analysisPosition: analysisPosition)
            }
        }
        return localizedMessageKey(key, languageCode: languageCode)
    }

    private static func coreErrorMessageKey(_ code: Int) -> String {
        switch code {
        case 100, 102, 104: "error.configuration"
        case 101: "error.authorization"
        case 103: "error.quota"
        case 200: "error.network"
        case 201: "error.timeout"
        case 202: "error.server"
        case 300...304, 500: "error.analysis"
        case 305: "error.questionnaire"
        case 400...402: "error.input"
        case 403: "error.busy"
        case 404: "error.cancelled"
        case 501: "error.result"
        case 502: "error.upload"
        default: "camera.critical_error"
        }
    }

    static func retakeMessage(
        for reasonCode: String?,
        partType: AISCPartType,
        analysisPosition: String?,
        isAlbum: Bool,
        languageCode: String? = nil
    ) -> String {
        let code = reasonCode?.uppercased() ?? ""
        let key: String
        switch code {
        case "MODEL_UNAVAILABLE": key = "error.analysis"
        case "SERVER_UNAVAILABLE": key = "error.server"
        case "INVALID_INPUT": key = "error.input"
        case "UNAUTHORIZED": key = "error.authorization"
        case "QUOTA_EXCEEDED": key = "error.quota"
        case "POSTPROCESS_FAILED": key = "error.result"
        case "PRE_IMAGE_RESOLUTION_TOO_LOW":
            key = "해상도가 너무 낮습니다. 더 선명한 사진으로 시도해 주세요."
        case "PRE_IMAGE_BIT_DEPTH_TOO_LOW": key = "photo.color_quality"
        default:
            if code.contains("BBOX_TOO_SMALL") || code.contains("TOO_FAR") {
                key = isAlbum ? albumFramingKey(partType: partType, larger: true) : "move_closer"
            } else if code.contains("BBOX_TOO_LARGE") || code.contains("TOO_CLOSE") {
                key = isAlbum ? albumFramingKey(partType: partType, larger: false) : "move_farther"
            } else if code.contains("BLUR") || code.contains("SCORE_LOW") {
                key = isAlbum ? "초점이 잘 맞는 선명한 사진을 선택해 주세요." : "hold_still"
            } else if code.contains("CLASSIFICATION_MISMATCH") || code.contains("DETECT_EMPTY") {
                switch partType {
                case .eye: key = isAlbum ? "눈이 잘 보이는 사진을 선택해 주세요." : "눈을 촬영해 주세요."
                case .teeth: key = isAlbum ? "치아가 잘 보이는 사진을 선택해 주세요." : "치아를 촬영해 주세요."
                case .skin: key = isAlbum ? albumSkinSelectionKey(partType: partType, analysisPosition: analysisPosition) : "피부를 촬영해 주세요."
                default: key = isAlbum ? "album.retake" : "popup.retake.title"
                }
            } else { key = isAlbum ? "album.retake" : "popup.retake.title" }
        }
        return localizedMessageKey(key, languageCode: languageCode)
    }

    static func albumDisplayMessage(
        for error: Error,
        partType: AISCPartType,
        analysisPosition: String?,
        languageCode: String? = nil
    ) -> String {
        let nsError = error as NSError
        guard nsError.domain == AISCErrorDomain else {
            return localizedMessageKey("error.analysis", languageCode: languageCode)
        }
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
            key = albumFramingKey(partType: partType, larger: true)
        case "더 멀리서 촬영해 주세요", "move_farther":
            key = albumFramingKey(partType: partType, larger: false)
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

    private static func albumFramingKey(partType: AISCPartType, larger: Bool) -> String {
        let part: String
        switch partType {
        case .eye: part = "eye"
        case .teeth: part = "teeth"
        case .skin: part = "skin"
        default: return "album.retake"
        }
        return "album.subject.\(part).\(larger ? "larger" : "full")"
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

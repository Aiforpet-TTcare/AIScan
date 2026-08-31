import Foundation

enum AIScanPDFStrings {
    static func localized(_ key: String, fallback: String) -> String {
        AIScanReferenceStrings.resourceBundle.localizedString(
            forKey: key,
            value: fallback,
            table: "AIScanPDF"
        )
    }

    static var defaultPetName: String {
        switch ScreeningPdfLocale.current {
        case .ko: return "반려동물"
        case .ja: return "ペット"
        case .it: return "Animale"
        case .th: return "สัตว์เลี้ยง"
        case .sv: return "Husdjur"
        case .en: return "Pet"
        }
    }

    static var skinSensitivity: String {
        AIScanReferenceStrings.localized(.skinSensitivity)
    }

    static var skinDryness: String {
        AIScanReferenceStrings.localized(.skinDryness)
    }

    static var skinRoughness: String {
        AIScanReferenceStrings.localized(.skinRoughness)
    }
}

enum PDFStrings {
    static var coverTitle: String { value("pdf.cover_title", "AI Health\nScreening Report") }
    static var printDateLabel: String { value("pdf.print_date", "Print date") }
    static var examinationDateLabel: String { value("pdf.examination_date", "Examination date") }
    static var layoutSummaryTitle: String { value("pdf.layout_summary_title", "AI Analysis Summary") }
    static var layoutDetailTitle: String { value("pdf.layout_detail_title", "Detailed AI Analysis") }
    static var layoutComprehensiveTitle: String { value("pdf.layout_comprehensive_title", "Comprehensive Opinion") }
    static var introTitle: String { value("pdf.intro_title", "AI health screening") }
    static var introText: String { value("pdf.intro_text", "Review the signs detected by AI and consult a veterinarian for an accurate diagnosis.") }
    static var abnormalSignTitle: String { value("pdf.abnormal_sign_title", "Abnormal Sign") }
    static var abnormal: String { value("pdf.abnormal", "Abnormal") }
    static var normal: String { value("pdf.normal", "Normal") }
    static var detailTitle: String { value("pdf.detail_title", "Detailed analysis result") }
    static var detailDescription: String { value("pdf.detail_description", "The AI analysis images and detected signs are shown below.") }
    static var detailNotDetected: String { value("pdf.detail_not_detected", "No sign was detected.") }
    static var capturedImageTitle: String { value("pdf.captured_image", "Captured image") }
    static var analysisImageTitle: String { value("pdf.analysis_image", "AI analysis image") }
    static var comprehensiveCause: String { value("pdf.comprehensive_cause", "There are various possible causes that could lead to such abnormal signs.") }
    static var comprehensiveRecommendation: String { value("pdf.comprehensive_recommendation", "Recommended examinations and care") }
    static var comprehensiveWarning: String { value("pdf.comprehensive_warning", "Please note") }
    static var comprehensiveFollowing: String { value("pdf.comprehensive_following", "The following care may help.") }
    static var comprehensiveNote: String { value("pdf.comprehensive_note", "This report is an AI screening aid and does not replace a veterinary diagnosis.") }
    static var infoMessage: String { value("pdf.info_message", "This report is provided for health-screening reference.") }
    static var exportButtonTitle: String { value("pdf.export_button", "Share PDF report") }
    static var exportFailedToast: String { value("pdf.export_failed", "Unable to create the PDF report.") }
    static var exportNoResultToast: String { value("pdf.export_no_result", "There is no result to export.") }

    static var coverTitleMultiline: String {
        coverTitle.replacingOccurrences(of: "\\n", with: "\n")
    }

    static func reportTitle(petName: String) -> String {
        value("pdf.title", "{petName}'s Health Screening Report")
            .replacingOccurrences(of: "{petName}", with: petName)
    }

    static func summaryTitle(petName: String, part: String) -> String {
        value("pdf.summary_title", "The abnormal findings observed in {petName}'s {part} are as follows.")
            .replacingOccurrences(of: "{petName}", with: petName)
            .replacingOccurrences(of: "{part}", with: part)
    }

    static func partLabel(_ part: String) -> String {
        switch part.uppercased() {
        case "EYE": return value("pdf.part_eye", "Eyes")
        case "SKIN": return value("pdf.part_skin", "Skin")
        case "TOOTH", "TEETH": return value("pdf.part_tooth", "Dental")
        default: return part
        }
    }

    static func headerTitle(part: String, pageTitle: String) -> String {
        "\(partLabel(part)) - \(pageTitle)"
    }

    static func subpartLabel(_ rawValue: String?, fallbackPart: String) -> String {
        switch rawValue?.uppercased() {
        case "EYER", "TRIGHT", "RIGHT": return value("pdf.subpart_right", "Right")
        case "EYEL", "TLEFT", "LEFT": return value("pdf.subpart_left", "Left")
        case "NOSE": return value("pdf.subpart_nose", "Nose")
        case "TCENTER", "CENTER", "FRONT": return value("pdf.subpart_front", "Front")
        case "EAR": return value("pdf.subpart_ear", "Ear")
        case "BELLY", "BODY": return value("pdf.subpart_body", "Body")
        case "FOOT", "PAW": return value("pdf.subpart_foot", "Foot")
        default: return partLabel(fallbackPart)
        }
    }

    private static func value(_ key: String, _ fallback: String) -> String {
        AIScanPDFStrings.localized(key, fallback: fallback)
    }
}

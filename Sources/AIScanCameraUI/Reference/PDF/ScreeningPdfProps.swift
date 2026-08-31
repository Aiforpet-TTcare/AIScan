//
//  ScreeningPdfProps.swift
//  AIScan
//
//  Render-ready props for the screening PDF report. Mirrors the web report
//  kit's `docs/data-contract.ts` (ScreeningPdfPropsContract / DiagnosesData /
//  Symptom / SymptomOrigin / SymptomDescription) but scoped to a SINGLE part
//  (the part the SDK just scanned) rather than the kit's eye/skin/tooth trio.
//

import Foundation

/// Locale the PDF content is rendered in. Mirrors the AIScan-supported
/// languages (ko/en/ja/it/th/sv). Any locale missing a particular key in the
/// bundled message JSON falls back to English.
enum ScreeningPdfLocale: String {
    case ko
    case en
    case ja
    case it
    case th
    case sv

    /// Key used to look up the kit's bundled message JSON (`detail`, `cause`,
    /// `inspection`, `care`, `care_normal`, `warning` are keyed by locale).
    var messageKey: String { rawValue }

    static var current: ScreeningPdfLocale {
        let code = Locale.preferredLanguages.first.flatMap { language in
            language.split(separator: "-").first.map(String.init)
        }?.lowercased()
        return code.flatMap(ScreeningPdfLocale.init(rawValue:)) ?? .en
    }
}

/// Per-symptom descriptive copy (ported from `message/data.json`).
struct ScreeningPdfSymptomDescription {
    let detail: String
    let cause: String
    let inspection: String
    let care: String
}

/// One observed position for a symptom (the CAM/heatmap thumbnail shown on the
/// detail page).
struct ScreeningPdfSymptomOrigin {
    let positionCode: String
    let positionName: String
    /// The AI CAM/heatmap image ("AI 분석 이미지"). May be nil → placeholder.
    let camImageUrl: URL?
    /// The scanned crop image ("촬영 이미지" / captured) shown to the LEFT of the
    /// heatmap. Defaulted so older call sites/tests that predate the pair compile.
    var capturedImageUrl: URL? = nil
    let isAbnormal: Bool
}

/// A single analyzed symptom row.
struct ScreeningPdfSymptom: Identifiable {
    let name: String
    let code: String
    let origin: [ScreeningPdfSymptomOrigin]
    let isAbnormal: Bool
    let description: ScreeningPdfSymptomDescription

    var id: String { code }
}

/// One position thumbnail shown in the summary grid.
struct ScreeningPdfPosition: Identifiable {
    let positionCode: String
    let positionName: String
    let cropImageUrl: URL?

    var id: String { positionCode }
}

/// One skin-feature meter (sensitivity / dryness / roughness) shown under the
/// summary table for SKIN reports only. Ported from dogtopia_wellness's
/// `SkinFeatureView`; `value` is a 0…total score.
struct ScreeningPdfSkinFeature: Identifiable {
    let name: String
    let value: Int
    let total: Int
    var id: String { name }
}

/// Aggregated diagnosis data for the single scanned part.
struct ScreeningPdfDiagnosesData {
    let positions: [ScreeningPdfPosition]
    let symptoms: [ScreeningPdfSymptom]
    let isAbnormal: Bool
    let createdAt: Date
    /// Free-form normal-case home-care guidance (warning + care_normal copy).
    let careNormalLines: [String]
    let warningLines: [String]
    /// Skin-feature meters appended under the summary table. Empty for non-skin
    /// parts (eye/tooth) so no extra block is rendered. Defaulted so existing
    /// call sites (and tests) that predate skin features keep compiling (var so
    /// it surfaces as a defaulted parameter in the memberwise initializer).
    var skinFeatures: [ScreeningPdfSkinFeature] = []
}

/// Top-level props for the screening PDF (single part).
struct ScreeningPdfProps {
    let locale: ScreeningPdfLocale
    /// "DOG" / "CAT".
    let petType: String
    /// Part code: "EYE" / "SKIN" / "TOOTH".
    let part: String
    let printDate: Date
    let petName: String
    let petDetail: String
    let diagnoses: ScreeningPdfDiagnosesData

    var isDog: Bool { petType.uppercased() == "DOG" }
}

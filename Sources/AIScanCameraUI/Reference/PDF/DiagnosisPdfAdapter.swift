import Foundation

@_spi(AIScanLifecycle)
/// Immutable value snapshot passed from the main-actor result UI to the
/// asynchronous PDF renderer.
public struct AIScanPDFReportInput: @unchecked Sendable {
    let viewModel: AIScanDisplayResultViewModel
    let petType: String
    let part: String
    let subpart: String?
    let petName: String
    let petDetail: String

    public init(
        viewModel: AIScanDisplayResultViewModel,
        petType: String,
        part: String,
        subpart: String?,
        petName: String,
        petDetail: String
    ) {
        self.viewModel = viewModel
        self.petType = petType
        self.part = part
        self.subpart = subpart
        self.petName = petName
        self.petDetail = petDetail
    }
}

@_spi(AIScanLifecycle)
public enum AIScanPDFPetDetailFormatter {
    public static func make(
        petType: String,
        petName: String?,
        petBreedName: String?,
        petBirthday: String?,
        petGender: String?
    ) -> String {
        let values = [petName, petBreedName, petBirthday, petGender]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !values.isEmpty { return values.joined(separator: " · ") }

        let isCat = petType.uppercased() == "CAT"
        switch ScreeningPdfLocale.current {
        case .ko: return isCat ? "고양이" : "강아지"
        case .ja: return isCat ? "猫" : "犬"
        case .it: return isCat ? "Gatto" : "Cane"
        case .th: return isCat ? "แมว" : "สุนัข"
        case .sv: return isCat ? "Katt" : "Hund"
        case .en: return isCat ? "Cat" : "Dog"
        }
    }
}

enum DiagnosisPdfAdapter {
    static func makeProps(from input: AIScanPDFReportInput) -> ScreeningPdfProps {
        let locale = ScreeningPdfLocale.current
        let store = ScreeningMessageStore.shared
        let part = normalizedPart(input.part)
        let petType = input.petType.uppercased() == "CAT" ? "CAT" : "DOG"
        let displaySymptoms = input.viewModel.analyzedSymptoms
        let analyzed = Dictionary(
            displaySymptoms.compactMap { symptom -> (String, AIScanDisplaySymptomViewModel)? in
                guard let code = symptom.code?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !code.isEmpty else { return nil }
                return (code.lowercased(), symptom)
            },
            uniquingKeysWith: { current, replacement in
                current.abnormalLevel >= replacement.abnormalLevel ? current : replacement
            }
        )
        let catalogCodes = store.symptomCodes(
            petType: petType,
            part: part,
            locale: locale
        )
        var orderedCodes = catalogCodes
        for symptom in displaySymptoms {
            guard let code = symptom.code, !code.isEmpty else { continue }
            if !orderedCodes.contains(where: { $0.caseInsensitiveCompare(code) == .orderedSame }) {
                orderedCodes.append(code)
            }
        }

        let positionURL = displaySymptoms.lazy
            .compactMap(\.cropImageURL)
            .first
            ?? displaySymptoms.lazy.compactMap(\.heatmapURL).first
        let positionName = PDFStrings.subpartLabel(input.subpart, fallbackPart: part)
        let symptoms = orderedCodes.map { code -> ScreeningPdfSymptom in
            let source = analyzed[code.lowercased()]
            let isAbnormal = (source?.abnormalLevel ?? 0) > 0
            let cropURL = source?.cropImageURL ?? positionURL
            let heatmapURL = source?.heatmapURL ?? cropURL
            return ScreeningPdfSymptom(
                name: source?.name.flatMap { $0.isEmpty ? nil : $0 } ?? displayName(for: code),
                code: code,
                origin: [
                    ScreeningPdfSymptomOrigin(
                        positionCode: input.subpart ?? part,
                        positionName: positionName,
                        camImageUrl: heatmapURL,
                        capturedImageUrl: cropURL,
                        isAbnormal: isAbnormal
                    )
                ],
                isAbnormal: isAbnormal,
                description: ScreeningPdfSymptomDescription(
                    detail: isAbnormal ? store.text(petType: petType, part: part, section: "detail", symptomCode: code, locale: locale) : "",
                    cause: isAbnormal ? store.text(petType: petType, part: part, section: "cause", symptomCode: code, locale: locale) : "",
                    inspection: isAbnormal ? store.text(petType: petType, part: part, section: "inspection", symptomCode: code, locale: locale) : "",
                    care: isAbnormal ? store.text(petType: petType, part: part, section: "care", symptomCode: code, locale: locale) : ""
                )
            )
        }
        let skinFeatures: [ScreeningPdfSkinFeature]
        if part == "SKIN", let features = input.viewModel.skinFeatures {
            skinFeatures = [
                .init(name: AIScanPDFStrings.skinSensitivity, value: features.sensitivity, total: features.total),
                .init(name: AIScanPDFStrings.skinDryness, value: features.dryness, total: features.total),
                .init(name: AIScanPDFStrings.skinRoughness, value: features.roughness, total: features.total),
            ]
        } else {
            skinFeatures = []
        }
        return ScreeningPdfProps(
            locale: locale,
            petType: petType,
            part: part,
            printDate: Date(),
            petName: input.petName.isEmpty ? AIScanPDFStrings.defaultPetName : input.petName,
            petDetail: input.petDetail,
            diagnoses: ScreeningPdfDiagnosesData(
                positions: [
                    ScreeningPdfPosition(
                        positionCode: input.subpart ?? part,
                        positionName: positionName,
                        cropImageUrl: positionURL
                    )
                ],
                symptoms: symptoms,
                // Questionnaire-only caution (CAUTION_Q) must not turn a
                // normal image into an abnormal image in the report.
                isAbnormal: displaySymptoms.contains { $0.abnormalLevel > 0 },
                createdAt: input.viewModel.analyzedAt,
                careNormalLines: store.careNormalLines(petType: petType, part: part, locale: locale),
                warningLines: store.warningLines(petType: petType, part: part, locale: locale),
                skinFeatures: skinFeatures
            )
        )
    }

    private static func normalizedPart(_ part: String) -> String {
        switch part.uppercased() {
        case "TEETH", "DENTAL": return "TOOTH"
        case "EAR", "BODY", "BELLY", "FOOT": return "SKIN"
        default: return part.uppercased().isEmpty ? "EYE" : part.uppercased()
        }
    }

    private static func displayName(for code: String) -> String {
        var result = ""
        for (index, scalar) in code.unicodeScalars.enumerated() {
            if index == 0 {
                result.append(Character(scalar).uppercased())
            } else if CharacterSet.uppercaseLetters.contains(scalar) {
                result.append(" ")
                result.append(Character(scalar))
            } else if scalar == "_" || scalar == "-" {
                result.append(" ")
            } else {
                result.append(Character(scalar))
            }
        }
        return result.isEmpty ? code : result
    }
}

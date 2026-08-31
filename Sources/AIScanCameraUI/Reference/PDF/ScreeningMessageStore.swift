//
//  ScreeningMessageStore.swift
//  AIScan
//
//  Loads the kit's bundled `screening_message.json` (ported verbatim from
//  `source/report/screening/message/data.json`) and exposes localized symptom
//  copy + per-part normal/warning guidance.
//
//  JSON shape:
//    { "DOG"|"CAT": { "EYE"|"SKIN"|"TOOTH": {
//        "detail":      { "ko"|"en"|"ja"|"it"|"th"|"sv"|...: { <symptomCode>: String } },
//        "cause":       { ... }, "inspection": { ... }, "care": { ... },
//        "care_normal": { "ko"|"en"|...: String },   // newline-separated
//        "warning":     { "ko"|"en"|...: String }    // newline-separated
//    } } }
//
//  A requested locale missing for some key falls back to "en", then "ko".
//

import Foundation

struct ScreeningMessageStore {

    /// petType -> part -> section -> locale -> (symptomCode -> text)
    private typealias CodeMap = [String: [String: [String: [String: String]]]]
    /// petType -> part -> section -> locale -> text
    private typealias StringMap = [String: [String: [String: [String: String]]]]

    private let raw: [String: Any]

    static let shared = ScreeningMessageStore()

    private init() {
        let bundle = AIScanReferenceStrings.resourceBundle
        let url = bundle.url(
            forResource: "screening_message",
            withExtension: "json",
            subdirectory: "PDF/Assets"
        ) ?? bundle.url(forResource: "screening_message", withExtension: "json")
        guard let url,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            raw = [:]
            return
        }
        raw = json
    }

    // MARK: - Lookups

    /// Per-symptom text for a section ("detail"/"cause"/"inspection"/"care").
    /// Symptom codes are matched case-insensitively because the on-device
    /// symptom codes are lowercased while the JSON uses camelCase.
    func text(
        petType: String,
        part: String,
        section: String,
        symptomCode: String,
        locale: ScreeningPdfLocale
    ) -> String {
        guard let codeMap = sectionDict(petType: petType, part: part, section: section, locale: locale) else {
            return ""
        }
        if let exact = codeMap[symptomCode] { return exact }
        let lowered = symptomCode.lowercased()
        for (key, value) in codeMap where key.lowercased() == lowered {
            return value
        }
        return ""
    }

    /// Newline-separated normal-case home-care guidance, split into lines.
    func careNormalLines(petType: String, part: String, locale: ScreeningPdfLocale) -> [String] {
        flatLines(petType: petType, part: part, section: "care_normal", locale: locale)
    }

    /// Newline-separated warning guidance, split into lines.
    func warningLines(petType: String, part: String, locale: ScreeningPdfLocale) -> [String] {
        flatLines(petType: petType, part: part, section: "warning", locale: locale)
    }

    /// Ordered catalog derived from the authoritative message payload. JSON
    /// object order is not contractual, so stable lexical order prevents a
    /// report from changing between runtime implementations.
    func symptomCodes(
        petType: String,
        part: String,
        locale: ScreeningPdfLocale
    ) -> [String] {
        let sections = ["detail", "cause", "inspection", "care"]
        var codes = Set<String>()
        for section in sections {
            codes.formUnion(
                sectionDict(
                    petType: petType,
                    part: part,
                    section: section,
                    locale: locale
                )?.keys ?? Dictionary<String, String>().keys
            )
        }
        let preferred = preferredOrder(petType: petType, part: part)
        let indexed = Dictionary(
            uniqueKeysWithValues: codes.map { ($0.lowercased(), $0) }
        )
        var ordered = preferred.compactMap { indexed[$0.lowercased()] }
        let selected = Set(ordered.map { $0.lowercased() })
        ordered.append(contentsOf: codes
            .filter { !selected.contains($0.lowercased()) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        return ordered
    }

    private func preferredOrder(petType: String, part: String) -> [String] {
        switch (petType.uppercased(), part.uppercased()) {
        case ("DOG", "EYE"):
            return ["epiphora", "ectropion", "cherry", "hyperemia", "opacity", "discharge", "chemosis", "blepharedema", "blepharoncus"]
        case ("DOG", "SKIN"):
            return ["redness", "pigmentation", "lichenification", "erosionUlcer", "pustuleCrust", "mass", "scale"]
        case ("CAT", "EYE"):
            return ["discharge", "cornealnecrosis", "blepharedema", "chemosis", "hyperemia"]
        case (_, "TOOTH"):
            return ["calculus", "inflammation"]
        default:
            return []
        }
    }

    // MARK: - Private

    private func partDict(petType: String, part: String) -> [String: Any]? {
        if let pet = raw[petType.uppercased()] as? [String: Any],
           let partNode = pet[part.uppercased()] as? [String: Any] {
            return partNode
        }
        // CAT lacks some parts (e.g. SKIN — cat ear/belly/foot all map to SKIN);
        // fall back to the DOG content for that part so descriptions aren't blank.
        if petType.uppercased() == "CAT",
           let dog = raw["DOG"] as? [String: Any],
           let partNode = dog[part.uppercased()] as? [String: Any] {
            return partNode
        }
        return nil
    }

    private func sectionDict(
        petType: String,
        part: String,
        section: String,
        locale: ScreeningPdfLocale
    ) -> [String: String]? {
        guard let partNode = partDict(petType: petType, part: part),
              let sectionNode = partNode[section] as? [String: Any] else {
            return nil
        }
        if let localized = sectionNode[locale.messageKey] as? [String: String] {
            return localized
        }
        // Fallback to English, then Korean, if the requested locale is absent.
        return (sectionNode["en"] as? [String: String])
            ?? (sectionNode["ko"] as? [String: String])
    }

    private func flatLines(
        petType: String,
        part: String,
        section: String,
        locale: ScreeningPdfLocale
    ) -> [String] {
        guard let partNode = partDict(petType: petType, part: part),
              let sectionNode = partNode[section] as? [String: Any] else {
            return []
        }
        let value = (sectionNode[locale.messageKey] as? String)
            ?? (sectionNode["en"] as? String)
            ?? (sectionNode["ko"] as? String)
            ?? ""
        return value
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

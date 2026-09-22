import Foundation
import AIScanCore

public struct AIScanSymptom: Codable, Equatable, Sendable {
    public let code: String?
    public let name: String?
    public let heatmapURL: URL?
    public let cropImageURL: URL?
    public let abnormalLevel: Int
    public let resultLabel: String?

    public init(
        code: String? = nil,
        name: String? = nil,
        heatmapURL: URL? = nil,
        cropImageURL: URL? = nil,
        abnormalLevel: Int = 0,
        resultLabel: String? = nil
    ) {
        self.code = code
        self.name = name
        self.heatmapURL = heatmapURL
        self.cropImageURL = cropImageURL
        self.abnormalLevel = abnormalLevel
        self.resultLabel = resultLabel
    }

    init(displaySymptom: AISCDisplaySymptom) {
        self.init(
            code: displaySymptom.code,
            name: displaySymptom.name,
            heatmapURL: displaySymptom.heatmapURL,
            cropImageURL: displaySymptom.cropImageURL,
            abnormalLevel: displaySymptom.abnormalLevel,
            resultLabel: displaySymptom.resultLabel
        )
    }
}

/// Original on-device questionnaire item returned to existing host apps.
public struct OnDeviceQuestion: Codable, Equatable, Sendable {
    public let text: String?
    public let select: String?

    public init(text: String? = nil, select: String? = nil) {
        self.text = text
        self.select = select
    }
}

public struct OnDeviceSymptomDetail: Codable, Equatable, Sendable {
    public let key: String?
    public let title: String?
    public let contents: [String]?

    public init(key: String? = nil, title: String? = nil, contents: [String]? = nil) {
        self.key = key
        self.title = title
        self.contents = contents
    }

    init(displayDetail: AISCDisplayDetail) {
        self.init(key: displayDetail.key, title: displayDetail.title, contents: displayDetail.contents)
    }
}

public struct OnDeviceDescription: Codable, Equatable, Sendable {
    public let title: String?
    public let contents: [String]?

    public init(title: String? = nil, contents: [String]? = nil) {
        self.title = title
        self.contents = contents
    }

    init(displayDetail: AISCDisplayDetail) {
        self.init(title: displayDetail.title, contents: displayDetail.contents)
    }
}

/// Original customer-facing symptom schema. Internal scores and model names
/// deliberately remain inside Core.
public struct OnDeviceSymptom: Codable, Equatable, Sendable {
    public let code: String?
    public let abnormLevel: Int?
    public let cropImageUrl: String?
    public let name: String?
    public let isAbnormal: Bool?
    public let resultLabel: String?
    public let heatmapUrl: String?
    public let details: [OnDeviceSymptomDetail]?

    public init(
        code: String? = nil,
        abnormLevel: Int? = nil,
        cropImageUrl: String? = nil,
        name: String? = nil,
        isAbnormal: Bool? = nil,
        resultLabel: String? = nil,
        heatmapUrl: String? = nil,
        details: [OnDeviceSymptomDetail]? = nil
    ) {
        self.code = code
        self.abnormLevel = abnormLevel
        self.cropImageUrl = cropImageUrl
        self.name = name
        self.isAbnormal = isAbnormal
        self.resultLabel = resultLabel
        self.heatmapUrl = heatmapUrl
        self.details = details
    }

    init(displaySymptom: AISCDisplaySymptom) {
        self.init(
            code: displaySymptom.code,
            abnormLevel: displaySymptom.abnormalLevel,
            cropImageUrl: displaySymptom.cropImageURL?.absoluteString,
            name: displaySymptom.name,
            isAbnormal: displaySymptom.abnormalLevel > 0,
            resultLabel: displaySymptom.resultLabel,
            heatmapUrl: displaySymptom.heatmapURL?.absoluteString,
            details: displaySymptom.details.map(OnDeviceSymptomDetail.init(displayDetail:))
        )
    }
}

public struct OnDeviceResponse: Codable, Equatable, Sendable {
    public let status: String?
    public let title: String?
    public let analyzedDate: String?
    public let description: OnDeviceDescription?
    public let symptoms: [OnDeviceSymptom]?

    public init(
        status: String? = nil,
        title: String? = nil,
        analyzedDate: String? = nil,
        description: OnDeviceDescription? = nil,
        symptoms: [OnDeviceSymptom]? = nil
    ) {
        self.status = status
        self.title = title
        self.analyzedDate = analyzedDate
        self.description = description
        self.symptoms = symptoms
    }
}

public struct AIScanContractResult: Codable, Equatable, @unchecked Sendable {
    public let schema: String
    /// Exact JSON-compatible partner payload. No SDK-side field is renamed,
    /// recalculated, filtered, or supplemented.
    public let payload: [String: Any]

    public init(schema: String, payload: [String: Any]) {
        self.schema = schema
        self.payload = payload
    }

    init(contractResult: AISCContractResult) {
        self.init(schema: contractResult.schema, payload: contractResult.payload)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.schema == rhs.schema && NSDictionary(dictionary: lhs.payload).isEqual(to: rhs.payload)
    }

    private enum CodingKeys: String, CodingKey { case schema, payload }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(String.self, forKey: .schema)
        payload = try container.decode([String: AIScanJSONValue].self, forKey: .payload)
            .mapValues(\.foundationValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(
            payload.mapValues { AIScanJSONValue(foundationValue: $0) },
            forKey: .payload
        )
    }
}

/// Result returned by `AIScanManager`. On-device fields retain the original
/// customer JSON contract; compact display fields remain convenience values.
public struct AIScanResult: Codable, Equatable, @unchecked Sendable {
    public let status: String
    public let diagnosisID: String?
    public let symptoms: [AIScanSymptom]
    /// Exact partner callback payload. The `schema`/`payload` transport
    /// envelope is never inserted into callback JSON.
    public let contractResult: [String: Any]?

    /// Optional transport metadata for hosts that opt into the structured API.
    /// Callback JSON always remains the direct `contractResult` dictionary.
    public var typedContractResult: AIScanContractResult? {
        guard let contractSchema, let contractResult else { return nil }
        return AIScanContractResult(schema: contractSchema, payload: contractResult)
    }

    private var contractSchema: String?

    public let petType: String?
    public let part: String?
    public let createdAt: Int?
    public let questions: [OnDeviceQuestion]?
    public let response: OnDeviceResponse?
    public let userId: String?
    public let petId: String?
    public let subPart: String?

    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanSymptom] = [],
        contractResult: [String: Any]? = nil,
        petType: String? = nil,
        part: String? = nil,
        createdAt: Int? = nil,
        questions: [OnDeviceQuestion]? = nil,
        response: OnDeviceResponse? = nil,
        userId: String? = nil,
        petId: String? = nil,
        subPart: String? = nil
    ) {
        self.status = status
        self.diagnosisID = diagnosisID
        self.symptoms = symptoms
        self.contractResult = contractResult
        self.contractSchema = nil
        self.petType = petType
        self.part = part
        self.createdAt = createdAt
        self.questions = questions
        self.response = response
        self.userId = userId
        self.petId = petId
        self.subPart = subPart
    }

    /// Creates a result with opt-in schema metadata while preserving legacy JSON.
    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanSymptom] = [],
        typedContractResult: AIScanContractResult
    ) {
        self.init(
            status: status,
            diagnosisID: diagnosisID,
            symptoms: symptoms,
            contractResult: typedContractResult
        )
    }

    /// Retains structured construction introduced in 3.0.10. The nonoptional
    /// argument keeps legacy dictionary and explicit `nil` calls unambiguous.
    public init(
        status: String,
        diagnosisID: String? = nil,
        symptoms: [AIScanSymptom] = [],
        contractResult: AIScanContractResult,
        petType: String? = nil,
        part: String? = nil,
        createdAt: Int? = nil,
        questions: [OnDeviceQuestion]? = nil,
        response: OnDeviceResponse? = nil,
        userId: String? = nil,
        petId: String? = nil,
        subPart: String? = nil
    ) {
        self.init(
            status: status,
            diagnosisID: diagnosisID,
            symptoms: symptoms,
            contractResult: contractResult.payload,
            petType: petType,
            part: part,
            createdAt: createdAt,
            questions: questions,
            response: response,
            userId: userId,
            petId: petId,
            subPart: subPart
        )
        contractSchema = contractResult.schema
    }

    /// Compact display-only conversion retained for source compatibility.
    init(displayResult: AISCDisplayResult) {
        self.init(
            status: displayResult.status,
            diagnosisID: displayResult.diagnosisID,
            symptoms: displayResult.symptoms.map(AIScanSymptom.init(displaySymptom:)),
            contractResult: displayResult.contractResult?.payload
        )
        contractSchema = displayResult.contractResult?.schema
    }

    init(
        legacyDisplayResult displayResult: AISCDisplayResult,
        petType: PetType,
        partType: PartType,
        subPart: String?,
        petId: String?,
        userId: String?,
        title: String? = nil,
        questionnaireDescription: String? = nil
    ) {
        if displayResult.contractResult != nil {
            self.init(displayResult: displayResult)
            return
        }

        let resolvedStatus = displayResult.status.uppercased()
        let callbackStatus = resolvedStatus == "CAUTION_Q" ? "CAUTION" : resolvedStatus
        let resultDescription: OnDeviceDescription?
        if resolvedStatus == "CAUTION_Q" {
            resultDescription = OnDeviceDescription(
                title: nil,
                contents: [questionnaireDescription ?? Self.defaultQuestionnaireDescription]
            )
        } else {
            resultDescription = displayResult.resultDetails.first.map(OnDeviceDescription.init(displayDetail:))
        }
        let onDeviceSymptoms = displayResult.analyzedSymptoms.map(OnDeviceSymptom.init(displaySymptom:))
        let answers = displayResult.questionnaireAnswers.map {
            OnDeviceQuestion(text: $0.prompt.text, select: $0.positive ? "Y" : "N")
        }

        self.init(
            status: "SUCCESS",
            diagnosisID: displayResult.diagnosisID,
            symptoms: displayResult.symptoms.map(AIScanSymptom.init(displaySymptom:)),
            contractResult: nil,
            petType: petType.rawValue.uppercased(),
            part: partType.legacyResultPart,
            createdAt: Int(displayResult.analyzedAt.timeIntervalSince1970 * 1_000),
            questions: answers.isEmpty ? nil : answers,
            response: OnDeviceResponse(
                status: callbackStatus,
                title: title ?? Self.defaultTitle(for: resolvedStatus),
                analyzedDate: Self.legacyAnalyzedDate(displayResult.analyzedAt),
                description: resultDescription,
                symptoms: onDeviceSymptoms
            ),
            userId: userId,
            petId: petId,
            subPart: subPart
        )
    }

    /// Exact JSON string used by the original string-completion API.
    public var jsonString: String? {
        if let contractResult,
           JSONSerialization.isValidJSONObject(contractResult),
           let data = try? JSONSerialization.data(withJSONObject: contractResult) {
            return String(data: data, encoding: .utf8)
        }
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Original `AIScanResult.string` callback surface retained for existing hosts.
    public var string: String? { jsonString }

    /// True when the partner payload is the service's failed-diagnosis DTO
    /// (`status: "ERROR"`), which the original service delivered as HTTP 500.
    var isContractError: Bool {
        (contractResult?["status"] as? String)?.uppercased() == "ERROR"
    }

    public var jsonObject: [String: Any]? {
        guard let jsonString,
              let value = try? JSONSerialization.jsonObject(with: Data(jsonString.utf8)) else {
            return nil
        }
        return value as? [String: Any]
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case diagnosisID = "diagnosisId"
        case symptoms
        case contractResult = "contract_result"
        case petType, part, createdAt, questions, response, userId, petId, subPart
    }

    public init(from decoder: Decoder) throws {
        let directPayload = try? decoder.singleValueContainer()
            .decode([String: AIScanJSONValue].self)
            .mapValues(\.foundationValue)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedContract = try container.decodeIfPresent(
            [String: AIScanJSONValue].self,
            forKey: .contractResult
        )?.mapValues(\.foundationValue)
        // Accept the persisted 3.0.10/11 envelope without changing direct
        // payloads or dictionaries containing additional partner fields.
        let wrappedContract: AIScanContractResult?
        if let decodedContract,
           Set(decodedContract.keys) == Set(["schema", "payload"]),
           let schema = decodedContract["schema"] as? String,
           let payload = decodedContract["payload"] as? [String: Any] {
            wrappedContract = AIScanContractResult(schema: schema, payload: payload)
        } else {
            wrappedContract = nil
        }
        let response = try container.decodeIfPresent(OnDeviceResponse.self, forKey: .response)
        let compactSymptoms = try container.decodeIfPresent([AIScanSymptom].self, forKey: .symptoms)
            ?? response?.symptoms?.filter { ($0.abnormLevel ?? 0) > 0 }.map(AIScanSymptom.init(onDeviceSymptom:))
            ?? []
        self.init(
            status: try container.decodeIfPresent(String.self, forKey: .status) ?? "",
            diagnosisID: try container.decodeIfPresent(String.self, forKey: .diagnosisID),
            symptoms: compactSymptoms,
            contractResult: wrappedContract?.payload ?? decodedContract ?? Self.directContractPayload(directPayload),
            petType: try container.decodeIfPresent(String.self, forKey: .petType),
            part: try container.decodeIfPresent(String.self, forKey: .part),
            createdAt: try container.decodeIfPresent(Int.self, forKey: .createdAt),
            questions: try container.decodeIfPresent([OnDeviceQuestion].self, forKey: .questions),
            response: response,
            userId: try container.decodeIfPresent(String.self, forKey: .userId),
            petId: try container.decodeIfPresent(String.self, forKey: .petId),
            subPart: try container.decodeIfPresent(String.self, forKey: .subPart)
        )
        contractSchema = wrappedContract?.schema
    }

    public func encode(to encoder: Encoder) throws {
        if let contractResult {
            var container = encoder.singleValueContainer()
            try container.encode(contractResult.mapValues { AIScanJSONValue(foundationValue: $0) })
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        if response != nil || petType != nil || part != nil {
            try container.encodeIfPresent(petType, forKey: .petType)
            try container.encodeIfPresent(part, forKey: .part)
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(questions, forKey: .questions)
            try container.encodeIfPresent(response, forKey: .response)
            try container.encodeIfPresent(userId, forKey: .userId)
            try container.encodeIfPresent(petId, forKey: .petId)
            try container.encodeIfPresent(subPart, forKey: .subPart)
            return
        }
        try container.encodeIfPresent(diagnosisID, forKey: .diagnosisID)
        try container.encode(symptoms, forKey: .symptoms)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.status == rhs.status
            && lhs.diagnosisID == rhs.diagnosisID
            && lhs.symptoms == rhs.symptoms
            && dictionariesEqual(lhs.contractResult, rhs.contractResult)
            && lhs.petType == rhs.petType
            && lhs.part == rhs.part
            && lhs.createdAt == rhs.createdAt
            && lhs.questions == rhs.questions
            && lhs.response == rhs.response
            && lhs.userId == rhs.userId
            && lhs.petId == rhs.petId
            && lhs.subPart == rhs.subPart
    }

    private static func directContractPayload(_ value: [String: Any]?) -> [String: Any]? {
        guard let value,
              value["contract_result"] == nil,
              value["diagId"] != nil,
              value["status"] != nil else {
            return nil
        }
        return value
    }

    private static func dictionariesEqual(_ lhs: [String: Any]?, _ rhs: [String: Any]?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (lhs?, rhs?): NSDictionary(dictionary: lhs).isEqual(to: rhs)
        default: false
        }
    }

    private static func legacyAnalyzedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd HH:mm"
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter.string(from: date)
    }

    private static func defaultTitle(for status: String) -> String {
        switch status {
        case "WARNING": "Seek Veterinary Care as Soon as Possible"
        case "CAUTION_Q": "Please monitor closely."
        case "CAUTION": "Monitor Closely"
        default: "No Concerning Signs at This Time"
        }
    }

    private static let defaultQuestionnaireDescription =
        "The image looks normal, but based on the questionnaire, your pet may still be feeling discomfort or pain that isn't visible in photos. Please keep a close eye and consider a veterinary visit if needed."
}

private extension AIScanSymptom {
    init(onDeviceSymptom symptom: OnDeviceSymptom) {
        self.init(
            code: symptom.code,
            name: symptom.name,
            heatmapURL: symptom.heatmapUrl.flatMap(URL.init(string:)),
            cropImageURL: symptom.cropImageUrl.flatMap(URL.init(string:)),
            abnormalLevel: symptom.abnormLevel ?? 0,
            resultLabel: symptom.resultLabel
        )
    }
}

private extension PartType {
    var legacyResultPart: String {
        switch self {
        case .eye: "EYE"
        case .tooth: "TOOTH"
        case .ear, .belly, .foot, .skin: "SKIN"
        }
    }
}

private enum AIScanJSONValue: Codable {
    case string(String), number(Double), bool(Bool)
    case object([String: AIScanJSONValue]), array([AIScanJSONValue]), null

    init(foundationValue: Any) {
        switch foundationValue {
        case let value as String: self = .string(value)
        case let value as NSNumber where CFGetTypeID(value) == CFBooleanGetTypeID(): self = .bool(value.boolValue)
        case let value as NSNumber: self = .number(value.doubleValue)
        case let value as [String: Any]: self = .object(value.mapValues(AIScanJSONValue.init(foundationValue:)))
        case let value as [Any]: self = .array(value.map(AIScanJSONValue.init(foundationValue:)))
        default: self = .null
        }
    }

    var foundationValue: Any {
        switch self {
        case let .string(value): value
        case let .number(value): value
        case let .bool(value): value
        case let .object(value): value.mapValues(\.foundationValue)
        case let .array(value): value.map(\.foundationValue)
        case .null: NSNull()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: AIScanJSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([AIScanJSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

@MainActor
public protocol AIScanResultViewControlling: AnyObject {
    func apply(result: AIScanResult)
}

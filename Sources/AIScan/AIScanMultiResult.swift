import Foundation
import AIScanCore
#if SWIFT_PACKAGE
import AIScanCameraUI
import AIScanReferenceUI
#endif

public struct AIScanPhotoError: Codable, Equatable, Sendable {
    public let domain: String
    public let code: Int
    public let message: String
    public let retryable: Bool
}

/// Typed per-photo metadata. Callback JSON contains direct results in selection order.
public struct AIScanPhotoResult: @unchecked Sendable {
    public let photoID: String
    public let photoIndex: Int
    public let status: String
    public let result: AIScanResult?
    public let error: AIScanPhotoError?
    public let reasonCode: String?
    public let message: String?
}

public extension AIScanResult {
    var isMultiMode: Bool { contractResult?["mode"] as? String == "multi" }

    /// Direct per-photo payloads, matching Android's multi-photo callback array.
    var jsonArray: [[String: Any]]? {
        guard isMultiMode, let entries = contractResult?["results"] as? [[String: Any]] else { return nil }
        return entries.map { entry in
            if var result = entry["result"] as? [String: Any] {
                if entry["status"] as? String == "RETRY" {
                    result["status"] = "RETRY"
                    for key in ["reasonCode", "message"] {
                        if let value = entry[key] { result[key] = value }
                    }
                }
                return result
            }
            return entry.filter { $0.key != "photoId" && $0.key != "photoIndex" }
        }
    }

    var photoResults: [AIScanPhotoResult]? {
        guard isMultiMode, let entries = contractResult?["results"] as? [[String: Any]] else { return nil }
        return entries.compactMap { entry in
            guard let id = entry["photoId"] as? String, let index = (entry["photoIndex"] as? NSNumber)?.intValue,
                  let status = entry["status"] as? String else { return nil }
            var result: AIScanResult?
            if status != "ERROR", let payload = entry["result"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: payload) {
                let decoded = try? JSONDecoder().decode(AIScanResult.self, from: data)
                result = AIScanResult(status: decoded?.status ?? "", diagnosisID: decoded?.diagnosisID,
                    symptoms: decoded?.symptoms ?? [], contractResult: payload,
                    petType: decoded?.petType, part: decoded?.part, createdAt: decoded?.createdAt,
                    questions: decoded?.questions, response: decoded?.response,
                    userId: decoded?.userId, petId: decoded?.petId, subPart: decoded?.subPart)
            }
            let error: AIScanPhotoError?
            if let raw = entry["error"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: raw) {
                error = try? JSONDecoder().decode(AIScanPhotoError.self, from: data)
            } else { error = nil }
            return AIScanPhotoResult(photoID: id, photoIndex: index, status: status, result: result,
                error: error, reasonCode: entry["reasonCode"] as? String, message: entry["message"] as? String)
        }
    }
}

extension AIScanResult {
    /// Read both Android-style direct arrays and previously persisted SDK wrappers.
    static func multiEntries(from payloads: [[String: Any]]) -> [[String: Any]] {
        payloads.enumerated().map { index, payload in
            if payload["photoId"] is String, payload["photoIndex"] is NSNumber,
               payload["status"] is String, payload["part"] == nil, payload["response"] == nil,
               payload["result"] is [String: Any] || payload["error"] is [String: Any] {
                return payload
            }
            let rawStatus = (payload["status"] as? String)?.uppercased() ?? ""
            let status: String
            switch rawStatus {
            case "RETRY": status = "RETRY"
            case "SUCCESS", "OK", "NORMAL", "CAUTION", "CAUTION_Q", "WARNING", "COMPLETED": status = "SUCCESS"
            default: status = "ERROR"
            }
            var entry: [String: Any] = ["photoId": "photo-\(index + 1)", "photoIndex": index + 1,
                "status": status, "result": payload]
            for key in ["error", "reasonCode", "message"] {
                if let value = payload[key] { entry[key] = value }
            }
            return entry
        }
    }

    init(multiOutcomes: [AIScanMultiPhotoOutcome], petType: PetType, partType: PartType,
         petId: String?, userId: String?) {
        var successCount = 0
        let entries: [[String: Any]] = multiOutcomes.map { outcome in
            var entry: [String: Any] = ["photoId": outcome.photoID, "photoIndex": outcome.photoIndex]
            if let display = outcome.result {
                let viewModel = AIScanDisplayResultViewModel(result: display)
                let single = AIScanResult(legacyDisplayResult: display, petType: petType, partType: partType,
                    subPart: (outcome.analysisSubpart ?? outcome.analysisPosition)?.uppercased(),
                    petId: petId, userId: userId, title: viewModel.legacyCallbackTitle,
                    questionnaireDescription: viewModel.legacyQuestionnaireDescription)
                entry["status"] = display.requiresRetake ? "RETRY" : "SUCCESS"
                entry["result"] = single.jsonObject ?? [:]
                if display.requiresRetake { entry["reasonCode"] = display.retakeReasonCode }
                else { successCount += 1 }
            } else {
                entry["status"] = "ERROR"
                if let error = outcome.error as NSError? {
                    entry["error"] = ["domain": error.domain, "code": error.code,
                        "message": outcome.errorMessage ?? "", "retryable": error.userInfo[AISCRetryableKey] as? Bool ?? false]
                }
            }
            if let message = outcome.errorMessage { entry["message"] = message }
            return entry
        }
        let status = successCount == multiOutcomes.count ? "SUCCESS" : successCount == 0 ? "ERROR" : "PARTIAL"
        let payload: [String: Any] = ["mode": "multi", "status": status,
            "photoCount": multiOutcomes.count, "results": entries]
        self.init(status: status, typedContractResult: AIScanContractResult(schema: "ttcare.multi.v2", payload: payload))
    }
}

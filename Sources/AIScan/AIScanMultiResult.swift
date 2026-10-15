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

/// One photo in selection order. The nested result retains its original JSON.
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

    /// Root JSON array delivered to apps in multi-photo mode.
    var jsonArray: [[String: Any]]? {
        guard isMultiMode else { return nil }
        return contractResult?["results"] as? [[String: Any]]
    }

    var photoResults: [AIScanPhotoResult]? {
        guard isMultiMode, let entries = contractResult?["results"] as? [[String: Any]] else { return nil }
        return entries.compactMap { entry in
            guard let id = entry["photoId"] as? String, let index = (entry["photoIndex"] as? NSNumber)?.intValue,
                  let status = entry["status"] as? String else { return nil }
            var result: AIScanResult?
            if let payload = entry["result"] as? [String: Any],
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

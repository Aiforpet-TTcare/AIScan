import XCTest
import UIKit
import AIScan

@MainActor
private final class CompatibilityCameraDelegate: AIScanCameraControllerDelegate {
    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didUpdate evaluation: AISCFrameEvaluation
    ) {}

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didCapture evaluation: AISCFrameEvaluation
    ) {}

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didProduce result: AISCDisplayResult
    ) {}

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didFail error: Error
    ) {}
}

@MainActor
private final class CompatibilityResultViewController: UIViewController, AIScanResultViewControlling {
    private(set) var receivedResult: AIScanResult?

    func apply(result: AIScanResult) {
        receivedResult = result
    }
}

final class AIScanCompatibilityTests: XCTestCase {
    @MainActor
    func testAIScanModuleReexportsSecureCoreAndPublicUI() {
        _ = AISCConfiguration.self
        _ = AISCSession.self
        _ = AIScanCameraController.self
        _ = AIScanDisplayResultViewModel.self

        XCTAssertEqual(PetType.dog.rawValue, "dog")
        XCTAssertEqual(PartType.eye.key, "EYE")
        XCTAssertEqual(PartType.tooth.platformPart, "teeth")
        XCTAssertEqual(PartType.skin.catalogKey, "BODY")
        XCTAssertEqual(PartType.foot.detailKey, "FOOT")

        _ = CompatibilityCameraDelegate()
    }

    @MainActor
    func testHighLevelManagerBuildsCameraWithoutExposingRawInference() throws {
        AIScanManager.configure(publishableKey: "tt_pk_test_compatibility")
        defer { AIScanManager.clearConfiguration() }

        let customResultController = CompatibilityResultViewController()
        var completionResults: [Result<AIScanResult, Error>] = []
        let camera = try AIScanManager.makeCameraViewController(
            petType: .dog,
            partType: .eye,
            petId: "pet-id",
            userId: "user-id",
            recordId: "record-id",
            displayMetadata: ["pet_name": "Bori"],
            resultViewController: customResultController,
            completion: { completionResults.append($0) }
        )

        XCTAssertEqual(camera.scanContext.petType, .dog)
        XCTAssertEqual(camera.scanContext.partType, .eye)
        XCTAssertEqual(camera.scanContext.petIdentifier, "pet-id")
        XCTAssertEqual(camera.scanContext.userIdentifier, "user-id")
        XCTAssertEqual(camera.scanContext.recordIdentifier, "record-id")
        XCTAssertEqual(camera.scanContext.displayMetadata, ["pet_name": "Bori"])

        let displayResult = AISCDisplayResult(
            status: "attention",
            diagnosisID: "diagnosis-id",
            symptoms: []
        )
        camera.onResult?(displayResult)
        camera.onClose?()

        XCTAssertEqual(customResultController.receivedResult?.status, "attention")
        XCTAssertEqual(completionResults.count, 1)
        if case let .success(result) = completionResults.first {
            XCTAssertEqual(result.diagnosisID, "diagnosis-id")
        } else {
            XCTFail("Expected one successful terminal result")
        }

        let showCamera: @MainActor (UIViewController) throws -> UIViewController = { presenter in
            try AIScanManager.showCamera(
                petType: .dog,
                partType: .eye,
                on: presenter
            )
        }
        _ = showCamera
    }

    @MainActor
    func testHighLevelManagerRequiresConfiguration() {
        AIScanManager.clearConfiguration()

        XCTAssertThrowsError(
            try AIScanManager.makeCameraViewController(
                petType: .dog,
                partType: .eye
            )
        ) { error in
            XCTAssertEqual(error as? AIScanManagerError, .notConfigured)
        }
    }

    func testHighLevelResultCopiesOnlyDisplaySafeFields() {
        let symptom = AISCDisplaySymptom(
            code: "display-code",
            name: "Display name",
            heatmapURL: URL(string: "https://example.com/heatmap.png"),
            cropImageURL: URL(string: "https://example.com/crop.png"),
            abnormalLevel: 2,
            resultLabel: "Observe"
        )
        let coreResult = AISCDisplayResult(
            status: "attention",
            diagnosisID: "diagnosis-id",
            symptoms: [symptom]
        )

        let result = AIScanResult(displayResult: coreResult)

        XCTAssertEqual(result.status, "attention")
        XCTAssertEqual(result.diagnosisID, "diagnosis-id")
        XCTAssertEqual(
            Mirror(reflecting: result).children.compactMap(\.label),
            ["status", "diagnosisID", "symptoms"]
        )
        XCTAssertEqual(result.symptoms, [
            AIScanSymptom(
                code: "display-code",
                name: "Display name",
                heatmapURL: URL(string: "https://example.com/heatmap.png"),
                cropImageURL: URL(string: "https://example.com/crop.png"),
                abnormalLevel: 2,
                resultLabel: "Observe"
            )
        ])
        XCTAssertEqual(
            Mirror(reflecting: result.symptoms[0]).children.compactMap(\.label),
            ["code", "name", "heatmapURL", "cropImageURL", "abnormalLevel", "resultLabel"]
        )
    }
}

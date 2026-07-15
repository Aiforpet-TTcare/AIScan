import XCTest
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
}

import XCTest
import AIScan

final class AIScanCompatibilityTests: XCTestCase {
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
    }
}

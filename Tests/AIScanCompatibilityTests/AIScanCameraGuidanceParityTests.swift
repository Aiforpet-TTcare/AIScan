import AIScanCore
import UIKit
import XCTest
@testable import AIScanCameraUI

@MainActor
final class AIScanCameraGuidanceParityTests: XCTestCase {
    func testGuidanceMessageChangesNeverHideOrRecreateTheOriginalBackground() throws {
        let overlay = TTOverlayViewController.instantiate(partType: .skin)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = overlay
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        overlay.loadViewIfNeeded()
        overlay.view.frame = window.bounds
        overlay.view.layoutIfNeeded()

        let background = try XCTUnwrap(overlay.messageContainer)
        let originalColor = background.backgroundColor

        XCTAssertFalse(background.isHidden)
        XCTAssertFalse(overlay.messageLabel.isHidden)
        XCTAssertEqual(overlay.messageLabel.alpha, 0, accuracy: 0.000_001)

        overlay.setMessage("가까이 이동해 주세요")
        let transition = TTOverlayViewController.makeMessageTransition()
        XCTAssertFalse(background.isHidden)
        XCTAssertFalse(overlay.messageLabel.isHidden)
        XCTAssertEqual(overlay.messageLabel.alpha, 1, accuracy: 0.000_001)
        XCTAssertEqual(overlay.messageLabel.text, "가까이 이동해 주세요")
        XCTAssertEqual(background.backgroundColor, originalColor)
        XCTAssertEqual(transition.type, .fade)
        XCTAssertEqual(transition.duration, 0.16, accuracy: 0.000_001)
        XCTAssertNil(background.layer.animationKeys())

        overlay.setMessage(nil)
        XCTAssertFalse(background.isHidden)
        XCTAssertFalse(overlay.messageLabel.isHidden)
        XCTAssertEqual(overlay.messageLabel.alpha, 0, accuracy: 0.000_001)
        XCTAssertNil(overlay.messageLabel.text)
        XCTAssertEqual(background.backgroundColor, originalColor)
    }

    func testSkinGuideNeverShowsTheEyeFocusIconOnItsInitialFrame() throws {
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .skin
        context.analysisPosition = "ear"

        let guide = PreviewGuideViewController.instantiate(context: context)
        guide.loadViewIfNeeded()

        let eyeIcon = try XCTUnwrap(guide.focusEyeIcon)
        XCTAssertTrue(eyeIcon.isHidden)
        XCTAssertEqual(eyeIcon.alpha, 1, accuracy: 0.000_001)
    }
}

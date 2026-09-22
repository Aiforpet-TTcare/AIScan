import UIKit
import XCTest
import AIScanCore
import AIScan
@_spi(AIScanLifecycle) @testable import AIScanCameraUI

/// The 1.x/2.x `(String?, Error?)` completion must keep its two outcomes:
/// `result` is the exact partner payload JSON on completion and `nil` otherwise,
/// and `error` is always `nil` exactly as those releases delivered it.
@MainActor
final class AIScanLegacyStringCompletionTests: XCTestCase {
    private let payload: [String: Any] = [
        "diagId": 12_345,
        "recordId": "dx-legacy",
        "status": "OK",
        "petId": "petId",
        "userId": NSNull(),
        "details": [["positionCode": "EYER", "diseaseCode": "opacity"]],
    ]

    override func setUp() {
        super.setUp()
        AIScanManager.configure(publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx")
    }

    override func tearDown() {
        AIScanManager.clearConfiguration()
        super.tearDown()
    }

    private func makeCamera(
        completion: @escaping (String?, Error?) -> Void
    ) throws -> AIScanCameraViewController {
        let camera = try AIScanManager.makeCameraViewController(
            petType: .dog,
            partType: .eye,
            enableResultView: false,
            completion: completion
        ) as! AIScanCameraViewController
        camera.loadViewIfNeeded()
        return camera
    }

    func testCompletedScanDeliversDirectPayloadJSONAndNilError() throws {
        var received: (result: String?, error: Error?)?
        let camera = try makeCamera { received = ($0, $1) }

        camera.onResult?(AISCDisplayResult(
            status: "completed",
            diagnosisID: "dx-legacy",
            symptoms: [],
            contractResult: AISCContractResult(
                schema: "ttcare.anomaly-check.v1",
                payload: payload
            )
        ))

        let callback = try XCTUnwrap(received)
        XCTAssertNil(callback.error)
        let json = try XCTUnwrap(callback.result)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        XCTAssertTrue(NSDictionary(dictionary: object).isEqual(to: payload))
        XCTAssertNil(object["schema"], "Transport envelope must not leak into legacy JSON")
        XCTAssertNil(object["payload"])
    }

    func testServerErrorDeliversNilLikeTheOriginalHTTP500() throws {
        var received: (result: String?, error: Error?)?
        let camera = try makeCamera { received = ($0, $1) }

        // Core reports a failed diagnosis (sdk_result.status ERROR) as a
        // non-retryable failure; the partner error DTO never becomes a result.
        camera.onFailure?(NSError(
            domain: AISCErrorDomain,
            code: AISCErrorCode.serverUnavailable.rawValue,
            userInfo: [AISCDisplayReasonKey: "UPSTREAM_FAILED", AISCRetryableKey: false]
        ))

        let callback = try XCTUnwrap(received)
        XCTAssertNil(callback.result, "1.x/2.x never received the error DTO")
        XCTAssertNil(callback.error)
    }

    func testFailedScanDeliversNilResultAndNilError() throws {
        var received: (result: String?, error: Error?)?
        let camera = try makeCamera { received = ($0, $1) }

        camera.onFailure?(NSError(
            domain: AISCErrorDomain,
            code: 1,
            userInfo: [AISCRetryableKey: false]
        ))

        let callback = try XCTUnwrap(received)
        XCTAssertNil(callback.result)
        XCTAssertNil(callback.error, "1.x/2.x never populated error")
    }

    func testRetryableFailureStaysInsideTheCamera() throws {
        var callbackCount = 0
        let camera = try makeCamera { _, _ in callbackCount += 1 }

        camera.onFailure?(NSError(
            domain: AISCErrorDomain,
            code: 1,
            userInfo: [AISCRetryableKey: true]
        ))

        XCTAssertEqual(callbackCount, 0, "Retake is handled by the camera, never by the host")
    }

    func testClosingWithoutAResultDeliversNilResultAndNilError() throws {
        var received: (result: String?, error: Error?)?
        let camera = try makeCamera { received = ($0, $1) }

        camera.onClose?()

        let callback = try XCTUnwrap(received)
        XCTAssertNil(callback.result)
        XCTAssertNil(callback.error, "1.x/2.x never populated error")
    }

    func testShowCameraAcceptsTheLegacyTwoArgumentTrailingClosure() throws {
        let host = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let camera = try AIScanManager.showCamera(
            petType: .dog,
            partType: .eye,
            on: host
        ) { result, error in
            _ = (result, error)
        }
        XCTAssertTrue(camera is AIScanCameraViewController)
    }
}

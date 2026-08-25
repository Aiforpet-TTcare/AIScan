import AVFoundation
import CoreMedia
import UIKit
import XCTest
import AIScan
@testable import AIScanCameraUI

private final class MockCameraEngine: NSObject, AISCCameraEngineControlling {
    weak var delegate: AISCCameraEngineDelegate?
    var automaticallyCapturesReadyFrames = false
    var analysisMode: AISCAnalysisMode { .onDevice }

    private(set) var preparedContexts: [AISCScanContext] = []
    private(set) var captureRequestCount = 0
    private(set) var resetCount = 0
    private(set) var cancelCount = 0

    func prepare(with context: AISCScanContext, completion: @escaping (Error?) -> Void) {
        preparedContexts.append(context)
        completion(nil)
    }

    func consume(_ sampleBuffer: CMSampleBuffer, device: AVCaptureDevice?) {}

    func requestCapture() {
        captureRequestCount += 1
    }

    func cameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? { nil }

    func cameraZoomFactor(for requestedFactor: CGFloat, device: AVCaptureDevice) -> CGFloat {
        requestedFactor
    }

    func applyCameraSessionPolicy(
        to session: AVCaptureSession,
        device: AVCaptureDevice,
        disable4K: Bool
    ) -> Bool {
        true
    }

    func applyCameraDevicePolicy(to device: AVCaptureDevice, enabled: Bool) {}

    func reset() {
        resetCount += 1
    }

    func cancel() {
        cancelCount += 1
    }

    func emitFrame(_ evaluation: AISCFrameEvaluation) {
        delegate?.cameraEngineDidUpdateFrameState(evaluation)
    }

    func emitCapture(_ evaluation: AISCFrameEvaluation) {
        delegate?.cameraEngineDidAcceptCaptureState(evaluation)
    }

    func emitProgress(_ progress: Double) {
        delegate?.cameraEngineDidUpdateProgress(progress)
    }

    func emitResult(_ result: AISCDisplayResult) {
        delegate?.cameraEngineDidComplete(result)
    }

    func emitFailure(_ error: Error) {
        delegate?.cameraEngineDidFail(error)
    }
}

@MainActor
private final class CameraEventProbe: AIScanCameraControllerDelegate {
    var onEvent: ((String) -> Void)?

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didUpdate evaluation: AISCFrameEvaluation
    ) {
        onEvent?("frame")
    }

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didCapture evaluation: AISCFrameEvaluation
    ) {
        onEvent?("capture")
    }

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didUpdateDiagnosisProgress progress: Double
    ) {
        onEvent?("progress:\(progress)")
    }

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didProduce result: AISCDisplayResult
    ) {
        onEvent?("result:\(result.status)")
    }

    func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error) {
        onEvent?("failure:\((error as NSError).code)")
    }
}

final class AIScanCameraUIStateTests: XCTestCase {
    @MainActor
    func testAnimatedProgressReachesVisibleAndAccessiblePercentage() async throws {
        let progress = TTProgressViewController.instantiate()
        progress.loadViewIfNeeded()

        progress.set(progress: 0.42, animated: true)
        try await Task.sleep(nanoseconds: 700_000_000)

        let label = try XCTUnwrap(
            progress.view.descendant(
                accessibilityIdentifier: "aiscan.camera.progress.percent"
            ) as? UILabel
        )
        XCTAssertEqual(label.text, "42")
        XCTAssertEqual(label.accessibilityValue, "42%")
    }

    @MainActor
    func testInjectedEngineOwnsControlCommands() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        var preparationError: Error?

        controller.automaticallyCapturesReadyFrames = true
        controller.prepare(context: context) { preparationError = $0 }
        controller.captureNextFrame()
        controller.reset()
        controller.cancel()

        XCTAssertTrue(engine.automaticallyCapturesReadyFrames)
        XCTAssertIdentical(engine.preparedContexts.first, context)
        XCTAssertNil(preparationError)
        XCTAssertEqual(engine.captureRequestCount, 1)
        XCTAssertEqual(engine.resetCount, 1)
        XCTAssertEqual(engine.cancelCount, 1)
    }

    @MainActor
    func testInjectedEngineEventsAreForwardedInDisplayOrder() async {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let probe = CameraEventProbe()
        controller.delegate = probe
        let receivedAllEvents = expectation(description: "all display-safe events")
        receivedAllEvents.expectedFulfillmentCount = 5
        var events: [String] = []
        probe.onEvent = {
            events.append($0)
            receivedAllEvents.fulfill()
        }

        let evaluation = makeEvaluation(captureAllowed: true)
        engine.emitFrame(evaluation)
        engine.emitCapture(evaluation)
        engine.emitProgress(0.42)
        engine.emitResult(AISCDisplayResult(status: "completed", diagnosisID: "dx-1", symptoms: []))
        engine.emitFailure(NSError(domain: AISCErrorDomain, code: 77))

        await fulfillment(of: [receivedAllEvents], timeout: 1)
        XCTAssertEqual(events, ["frame", "capture", "progress:0.42", "result:completed", "failure:77"])
    }

    @MainActor
    func testCameraViewRendersCaptureProgressAndRetryStatesFromEngine() async throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let camera = AIScanCameraViewController(cameraController: controller, context: context)
        camera.beginsScanningAutomatically = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        engine.emitCapture(makeEvaluation(captureAllowed: true))
        engine.emitProgress(0.42)
        try await Task.sleep(nanoseconds: 100_000_000)

        let progressLabel = try XCTUnwrap(
            camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.progress.percent"
            ) as? UILabel
        )
        XCTAssertEqual(progressLabel.accessibilityValue, "42%")

        let retryEngine = MockCameraEngine()
        let retryController = AIScanCameraController(cameraEngine: retryEngine)
        let retryCamera = AIScanCameraViewController(cameraController: retryController, context: context)
        retryCamera.beginsScanningAutomatically = false
        window.rootViewController = retryCamera
        retryCamera.loadViewIfNeeded()

        let retryError = NSError(
            domain: AISCErrorDomain,
            code: 88,
            userInfo: [AISCRetryableKey: true, AISCDisplayReasonKey: "retry-safe"]
        )
        retryEngine.emitFailure(retryError)
        var retryButton: UIView?
        for _ in 0..<20 where retryButton == nil {
            try await Task.sleep(nanoseconds: 100_000_000)
            retryButton = retryCamera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.retry"
            )
        }

        XCTAssertNotNil(retryButton)
    }

    private func makeEvaluation(captureAllowed: Bool) -> AISCFrameEvaluation {
        AISCFrameEvaluation(
            scanState: captureAllowed ? .captureReady : .tracking,
            captureDecision: captureAllowed ? .ready : .continue,
            guidanceCode: .none,
            captureAllowed: captureAllowed,
            normalizedProgress: captureAllowed ? 1 : 0.5,
            displayMessageKey: nil,
            overlayHints: nil
        )
    }
}

private extension UIView {
    func descendant(accessibilityIdentifier: String) -> UIView? {
        if self.accessibilityIdentifier == accessibilityIdentifier { return self }
        return subviews.lazy.compactMap {
            $0.descendant(accessibilityIdentifier: accessibilityIdentifier)
        }.first
    }
}

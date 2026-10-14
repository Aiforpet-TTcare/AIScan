import CoreImage
import ObjectiveC
import UIKit
import XCTest
import AIScanCore
@testable import AIScan
@testable import AIScanCameraUI

@MainActor
final class AIScanMultiPhotoTests: XCTestCase {
    private func fixture(_ count: Int) -> (AIScanMultiPhotoCoordinator, [MockCameraEngine]) {
        let engines = (0..<count).map { _ in MockCameraEngine() }
        engines.forEach { $0.analysisMode = AISCAnalysisMode(rawValue: 1)! }
        var next = 0
        let coordinator = AIScanMultiPhotoCoordinator {
            defer { next += 1 }
            return AIScanCameraController(cameraEngine: engines[next])
        }
        return (coordinator, engines)
    }

    private func append(_ coordinator: AIScanMultiPhotoCoordinator, position: String = "left") -> Bool {
        let context = AISCScanContext()
        context.petType = .dog; context.partType = .eye
        context.analysisSubpart = position
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 120)).image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 120))
        }
        return coordinator.append(input: AISCImageInput(imageURL: URL(fileURLWithPath: "/fixture/original.jpg")),
                                  preview: image, context: context)
    }

    // The opaque Core token is only forwarded by Swift. Network behavior is
    // verified separately with real Core transport tests.
    private func uploadedToken() -> AISCUploadedPhoto {
        class_createInstance(AISCUploadedPhoto.self, 0) as! AISCUploadedPhoto
    }
    private func drain() async throws { try await Task.sleep(nanoseconds: 80_000_000) }

    func testPreuploadsImmediatelyThenStartsFourAnalysesWithoutWaitingForOneAnother() async throws {
        let (coordinator, engines) = fixture(4)
        var callbacks: [[AIScanMultiPhotoOutcome]] = []
        coordinator.onComplete = { callbacks.append($0) }
        for index in 0..<4 { XCTAssertTrue(append(coordinator, position: index % 2 == 0 ? "left" : "right")) }
        try await drain()
        XCTAssertEqual(engines.map { $0.uploadedPhotoInputs.count }, [1, 1, 1, 1])
        for engine in engines { engine.uploadCompletions[0](uploadedToken(), nil) }
        try await drain()
        XCTAssertEqual(engines.map { $0.diagnosedUploadedPhotos.count }, [0, 0, 0, 0])
        XCTAssertTrue(callbacks.isEmpty)
        coordinator.analyze()
        XCTAssertEqual(engines.map { $0.diagnosedUploadedPhotos.count }, [1, 1, 1, 1])
        for index in [3, 1, 2] {
            engines[index].emitResult(AISCDisplayResult(status: "completed", diagnosisID: "diag-\(index)", symptoms: []))
        }
        try await drain()
        XCTAssertTrue(callbacks.isEmpty)
        engines[0].emitFailure(NSError(domain: AISCErrorDomain, code: AISCErrorCode.requestTimedOut.rawValue))
        try await drain()
        XCTAssertEqual(callbacks.count, 1)
        XCTAssertEqual(callbacks[0].map(\.photoIndex), [1, 2, 3, 4])
        XCTAssertEqual(callbacks[0].compactMap { $0.result?.diagnosisID }, ["diag-1", "diag-2", "diag-3"])
        XCTAssertNotNil(callbacks[0][0].error)
        XCTAssertEqual(callbacks[0].map(\.analysisSubpart), ["left", "right", "left", "right"])
        XCTAssertEqual(coordinator.progress, 1)
        engines[0].emitFailure(NSError(domain: "duplicate", code: 1))
        coordinator.analyze()
        try await drain()
        XCTAssertEqual(callbacks.count, 1)
        coordinator.cancel()
    }

    func testConfirmDuringUploadJoinsLaterAndUploadFailureDoesNotAbortOtherPhotos() async throws {
        let (coordinator, engines) = fixture(3)
        var returned: [AIScanMultiPhotoOutcome] = []
        coordinator.onComplete = { returned = $0 }
        for _ in engines { XCTAssertTrue(append(coordinator)) }
        try await drain()
        engines[0].uploadCompletions[0](uploadedToken(), nil)
        engines[1].uploadCompletions[0](nil, NSError(domain: AISCErrorDomain, code: AISCErrorCode.networkUnavailable.rawValue))
        try await drain()
        XCTAssertTrue(returned.isEmpty)
        coordinator.analyze()
        XCTAssertEqual(engines.map { $0.diagnosedUploadedPhotos.count }, [1, 0, 0])
        engines[2].uploadCompletions[0](uploadedToken(), nil)
        try await drain()
        XCTAssertEqual(engines.map { $0.diagnosedUploadedPhotos.count }, [1, 0, 1])
        for index in [2, 0] { engines[index].emitResult(AISCDisplayResult(status: "completed", diagnosisID: "d\(index)", symptoms: [])) }
        try await drain()
        XCTAssertEqual(returned.count, 3)
        XCTAssertNotNil(returned[1].error)
        XCTAssertNotEqual(returned[1].errorMessage, returned[1].error?.localizedDescription)
        coordinator.cancel()
    }

    func testCapacityRemovalAndCancellationIgnoreLateCallbacks() async throws {
        let (coordinator, engines) = fixture(5)
        for _ in 0..<4 { XCTAssertTrue(append(coordinator)) }
        XCTAssertFalse(append(coordinator))
        try await drain()
        coordinator.remove(id: coordinator.items[1].id)
        XCTAssertEqual(engines.map(\.cancelCount), [0, 1, 0, 0, 0])
        XCTAssertTrue(append(coordinator))
        try await drain()
        engines[1].uploadCompletions[0](uploadedToken(), nil)
        var callbackCount = 0
        coordinator.onComplete = { _ in callbackCount += 1 }
        coordinator.cancel()
        for engine in engines where !engine.uploadCompletions.isEmpty {
            engine.uploadCompletions[0](uploadedToken(), nil)
            engine.emitResult(AISCDisplayResult(status: "completed", diagnosisID: "late", symptoms: []))
        }
        try await drain()
        XCTAssertEqual(callbackCount, 0)
        XCTAssertTrue(coordinator.items.isEmpty)
        XCTAssertTrue(engines.allSatisfy { $0.diagnosedUploadedPhotos.isEmpty })
    }

    func testMatchingQuestionnairesAreAnsweredOnceForAllIndependentSessions() async throws {
        let (coordinator, engines) = fixture(3)
        for _ in engines { XCTAssertTrue(append(coordinator)) }
        try await drain()
        for engine in engines { engine.uploadCompletions[0](uploadedToken(), nil) }
        try await drain()
        coordinator.analyze()
        let prompts = [AISCQuestionnairePrompt(identifier: "q1", text: "Question 1"), AISCQuestionnairePrompt(identifier: "q2", text: "Question 2")]
        var presentations = 0
        var answer: (([AISCQuestionnaireAnswer]) -> Void)?
        coordinator.onQuestionnaire = { _, completion in presentations += 1; answer = completion }
        for engine in engines.prefix(2) { engine.emitQuestionnaire(AISCQuestionnaire(prompts: prompts)) }
        try await drain()
        XCTAssertEqual(presentations, 1)
        answer?(prompts.map { AISCQuestionnaireAnswer(prompt: $0, positive: true) })
        engines[2].emitQuestionnaire(AISCQuestionnaire(prompts: prompts))
        try await drain()
        XCTAssertEqual(presentations, 1)
        XCTAssertEqual(engines.map { $0.submittedQuestionnaireAnswers.count }, [1, 1, 1])
        XCTAssertTrue(engines.allSatisfy { $0.submittedQuestionnaireAnswers[0].allSatisfy(\.positive) })
        coordinator.cancel()
    }

    func testCapturedPhotoCollectionBridgeIsVisibleToObjectiveCCore() async throws {
        let controller = AIScanCameraController(cameraEngine: MockCameraEngine())
        let probe = MultiCaptureCollectionProbe()
        controller.delegate = probe
        let selector = NSSelectorFromString("cameraEngineDidCollectImageInput:")
        XCTAssertTrue(controller.responds(to: selector))
        guard controller.responds(to: selector) else { return }
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 64,
            kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
        let input = AISCImageInput(pixelBuffer: try XCTUnwrap(buffer))
        // Core uses Objective-C optional-selector dispatch, not a direct Swift
        // call. Exercise that exact boundary before checking the UI event.
        controller.perform(selector, with: input)
        try await drain()
        XCTAssertEqual(probe.inputs.count, 1)
        XCTAssertTrue(probe.inputs.first === input)
        XCTAssertEqual(probe.preview?.size, CGSize(width: 64, height: 64))
    }

    func testDefaultFlagRemainsFalseAndCollectionIsOptIn() {
        let context = AISCScanContext(); context.partType = .eye; context.petType = .dog
        let engine = MockCameraEngine()
        let single = AIScanCameraViewController(cameraController: AIScanCameraController(cameraEngine: engine), context: context)
        single.beginsScanningAutomatically = false
        single.loadViewIfNeeded()
        XCTAssertFalse(single.enableMultiMode)
        XCTAssertFalse(engine.photoCollectionEnabled)
        let multiEngine = MockCameraEngine()
        let multi = AIScanCameraViewController(cameraController: AIScanCameraController(cameraEngine: multiEngine), context: context, stackDismisser: MultiTestStackDismisser(), enableMultiMode: true)
        multi.beginsScanningAutomatically = false
        multi.loadViewIfNeeded()
        XCTAssertTrue(multi.enableMultiMode)
        XCTAssertTrue(multiEngine.photoCollectionEnabled)
    }

    func testReviewGridControlSitsBesideShutterAndTracksCaptureAvailability() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844)] {
            let context = AISCScanContext(); context.partType = .eye; context.petType = .dog
            let multi = AIScanCameraViewController(cameraController: AIScanCameraController(cameraEngine: MockCameraEngine()),
                context: context, stackDismisser: MultiTestStackDismisser(), enableMultiMode: true,
                multiPhotoControllerFactory: { AIScanCameraController(cameraEngine: MockCameraEngine()) })
            multi.beginsScanningAutomatically = false
            multi.loadViewIfNeeded(); multi.view.frame = CGRect(origin: .zero, size: size)
            multi.view.layoutIfNeeded()
            let surface = try XCTUnwrap(multi.children.compactMap { $0 as? CameraViewController }.first)
            surface.view.layoutIfNeeded(); surface.setPreparing(false)
            let grid = surface.photoReviewButton
            XCTAssertTrue(grid.isHidden)
            XCTAssertFalse(grid.isEnabled)
            surface.setPhotoReview(count: 1, available: true)
            XCTAssertFalse(grid.isHidden)
            XCTAssertTrue(grid.isEnabled)
            XCTAssertNil(grid.title(for: .normal))
            XCTAssertNotNil(grid.image(for: .normal))
            XCTAssertEqual(grid.bounds.size, CGSize(width: 44, height: 44))
            XCTAssertEqual(grid.frame.midY, surface.captureButtonContainer.convert(surface.captureButtonContainer.bounds, to: surface.view).midY, accuracy: 0.5)
            XCTAssertGreaterThan(grid.frame.minX, surface.captureButtonContainer.frame.maxX)
            XCTAssertEqual(surface.albumButton.frame.minX, surface.view.bounds.width - grid.frame.maxX, accuracy: 0.5)
            surface.setCaptureAttempt(active: true)
            XCTAssertTrue(grid.isHidden); XCTAssertFalse(grid.isEnabled)
            surface.setCaptureAttempt(active: false)
            XCTAssertFalse(grid.isHidden); XCTAssertTrue(grid.isEnabled)
            let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: multi.view.bounds).image { multi.view.layer.render(in: $0.cgContext) })
            attachment.name = "camera-review-grid-\(Int(size.width))"; attachment.lifetime = .keepAlways; add(attachment)
            surface.setPhotoReview(count: 0, available: true)
            XCTAssertTrue(grid.isHidden, "Removing the last photo hides review again.")
            XCTAssertFalse(grid.isEnabled)
        }
    }

    func testReviewUsesFourFixedSquareFillFramesAndRemovalRemainsTappableOnSmallScreens() async throws {
        let (coordinator, _) = fixture(4)
        for _ in 0..<4 { XCTAssertTrue(append(coordinator)) }
        let review = AIScanMultiPhotoReviewViewController(allowsAlbum: true)
        review.refresh(coordinator.items)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        window.rootViewController = review; window.makeKeyAndVisible()
        defer { window.isHidden = true; coordinator.cancel() }
        review.loadViewIfNeeded(); review.view.layoutIfNeeded()
        let all = descendants(review.view)
        let frames = all.filter { $0.accessibilityIdentifier?.hasPrefix("aiscan.multi.photo.") == true }
        XCTAssertEqual(frames.count, 4)
        for frame in frames {
            XCTAssertEqual(frame.bounds.width, frame.bounds.height, accuracy: 0.5)
            XCTAssertGreaterThan(frame.bounds.width, 100)
            let image = try XCTUnwrap(frame.subviews.compactMap { $0 as? UIImageView }.first)
            XCTAssertEqual(image.contentMode, .scaleAspectFill)
        }
        var cameraReturns = 0
        review.onCamera = { cameraReturns += 1 }
        for frame in frames {
            let button = try XCTUnwrap(frame as? UIButton)
            for target in button.allTargets {
                for action in button.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                    (target as? NSObject)?.perform(NSSelectorFromString(action), with: button)
                }
            }
        }
        XCTAssertEqual(cameraReturns, 4, "Every occupied slot returns to camera, including at capacity.")
        XCTAssertNil(review.presentedViewController)
        let add = try XCTUnwrap(all.first { $0.accessibilityIdentifier == "aiscan.multi.add" })
        XCTAssertTrue(add.isHidden)
        let remove = try XCTUnwrap(all.first { $0.accessibilityIdentifier == "aiscan.multi.remove.2" } as? UIButton)
        var removed: String?
        review.onRemove = { removed = $0 }
        XCTAssertEqual(remove.tag, 1)
        XCTAssertFalse(remove.allTargets.isEmpty)
        for target in remove.allTargets {
            for action in remove.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                (target as? NSObject)?.perform(NSSelectorFromString(action), with: remove)
            }
        }
        XCTAssertEqual(removed, coordinator.items[1].id)
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: review.view.bounds).image { _ in review.view.layer.render(in: UIGraphicsGetCurrentContext()!) })
        attachment.name = "multi-review-320x568"; attachment.lifetime = .keepAlways; addAttachment(attachment)
    }

    func testReviewOffersCameraAndAlbumDirectlyAndHidesBothAtCapacity() async throws {
        let (coordinator, _) = fixture(4)
        XCTAssertTrue(append(coordinator))
        let review = AIScanMultiPhotoReviewViewController(allowsAlbum: true)
        review.refresh(coordinator.items)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = review; window.makeKeyAndVisible()
        defer { window.isHidden = true; coordinator.cancel() }
        review.view.layoutIfNeeded()
        XCTAssertEqual(review.traitCollection.userInterfaceStyle, .dark)
        for frame in descendants(review.view) where frame.accessibilityIdentifier?.hasPrefix("aiscan.multi.photo.") == true {
            XCTAssertEqual(frame.bounds.width, frame.bounds.height, accuracy: 0.5)
        }
        let all = descendants(review.view)
        let camera = try XCTUnwrap(all.first { $0.accessibilityIdentifier == "aiscan.multi.add" } as? UIButton)
        let album = try XCTUnwrap(all.first { $0.accessibilityIdentifier == "aiscan.multi.album" } as? UIButton)
        var cameras = 0; var albums = 0
        review.onCamera = { cameras += 1 }; review.onAlbum = { albums += 1 }
        for button in [camera, album] {
            XCTAssertFalse(button.isHidden)
            for target in button.allTargets {
                for action in button.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                    (target as? NSObject)?.perform(NSSelectorFromString(action), with: button)
                }
            }
        }
        let empty = try XCTUnwrap(all.first { $0.accessibilityIdentifier == "aiscan.multi.photo.2" } as? UIButton)
        for target in empty.allTargets {
            for action in empty.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                (target as? NSObject)?.perform(NSSelectorFromString(action), with: empty)
            }
        }
        var backs = 0
        review.onBack = { backs += 1 }
        let back = try XCTUnwrap(all.first { $0.accessibilityIdentifier == "aiscan.multi.back" } as? UIButton)
        for target in back.allTargets {
            for action in back.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                (target as? NSObject)?.perform(NSSelectorFromString(action), with: back)
            }
        }
        XCTAssertEqual(cameras, 2); XCTAssertEqual(albums, 1); XCTAssertEqual(backs, 1)
        XCTAssertNil(review.presentedViewController)
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: review.view.bounds).image { review.view.layer.render(in: $0.cgContext) })
        attachment.name = "multi-dark-review-one-photo"; attachment.lifetime = .keepAlways; add(attachment)
        for _ in 0..<3 { XCTAssertTrue(append(coordinator)) }
        review.refresh(coordinator.items)
        XCTAssertTrue(camera.isHidden); XCTAssertTrue(album.isHidden)
    }

    func testAggregateIncludesSuccessRetakeAndNetworkFailureWithoutChangingNestedPayloads() throws {
        let native: [String: Any] = ["status": "SUCCESS", "response": ["symptoms": [["code": "opacity", "polygons": [[12.25, 23.5, 35.75, 47.125]]]]]]
        let success = AISCDisplayResult(status: "completed", diagnosisID: "success", symptoms: [], contractResult: AISCContractResult(schema: "native.v1", payload: native))
        let retryPayload: [String: Any] = ["status": "RETRY", "error": ["code": "PRE_EYE_DETECT_BBOX_TOO_SMALL"]]
        let retry = AISCDisplayResult(status: "RETRY", diagnosisID: "retry", symptoms: [], contractResult: AISCContractResult(schema: "native.v1", payload: retryPayload), requiresRetake: true, retakeReasonCode: "PRE_EYE_DETECT_BBOX_TOO_SMALL")
        let outcomes = [
            AIScanMultiPhotoOutcome(photoID: "a", photoIndex: 1, result: success, error: nil, errorMessage: nil, analysisSubpart: "left", analysisPosition: nil),
            AIScanMultiPhotoOutcome(photoID: "b", photoIndex: 2, result: retry, error: nil, errorMessage: "Choose a closer photo", analysisSubpart: "right", analysisPosition: nil),
            AIScanMultiPhotoOutcome(photoID: "c", photoIndex: 3, result: nil, error: NSError(domain: AISCErrorDomain, code: 408, userInfo: [AISCRetryableKey: true]), errorMessage: "Please try again", analysisSubpart: "left", analysisPosition: nil)
        ]
        let result = AIScanResult(multiOutcomes: outcomes, petType: .dog, partType: .eye, petId: nil, userId: nil)
        XCTAssertEqual(result.status, "PARTIAL")
        XCTAssertEqual(result.typedContractResult?.schema, "ttcare.multi.v2")
        let photos = try XCTUnwrap(result.photoResults)
        XCTAssertEqual(photos.map(\.status), ["SUCCESS", "RETRY", "ERROR"])
        XCTAssertEqual(photos.first?.result?.jsonObject as NSDictionary?, native as NSDictionary)
        XCTAssertEqual(photos.dropFirst().first?.result?.jsonObject as NSDictionary?, retryPayload as NSDictionary)
        XCTAssertEqual(photos.last?.error?.retryable, true)
        XCTAssertEqual(photos.last?.message, "Please try again")
        XCTAssertNil(result.jsonObject)
        XCTAssertEqual(result.jsonArray?.count, 3)
        let failed = AIScanResult(multiOutcomes: Array(outcomes.suffix(1)), petType: .dog, partType: .eye, petId: nil, userId: nil)
        XCTAssertEqual(failed.status, "ERROR")
        XCTAssertEqual(failed.photoResults?.count, 1)
    }

    private func addAttachment(_ attachment: XCTAttachment) { add(attachment) }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    func testRootArrayRoundTripPreservesOrderedFailuresAndNativeResults() throws {
        let entries: [[String: Any]] = [
            ["photoId": "a", "photoIndex": 1, "status": "ERROR", "error": ["domain": "network", "code": 408, "message": "Try again", "retryable": true]],
            ["photoId": "b", "photoIndex": 2, "status": "SUCCESS", "result": ["status": "SUCCESS", "response": ["symptoms": [["polygons": [[1, 2, 3, 4]]]]]]],
        ]
        let decoded = try JSONDecoder().decode(AIScanResult.self, from: JSONSerialization.data(withJSONObject: entries))
        XCTAssertTrue(decoded.isMultiMode)
        XCTAssertEqual(decoded.status, "PARTIAL")
        XCTAssertEqual(decoded.photoResults?.map(\.photoIndex), [1, 2])
        XCTAssertEqual(decoded.photoResults?.first?.error?.code, 408)
        XCTAssertEqual(decoded.jsonArray as NSArray?, entries as NSArray)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded))
        XCTAssertEqual(encoded as? NSArray, entries as NSArray)
        let callback = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(decoded.string).utf8))
        XCTAssertEqual(callback as? NSArray, entries as NSArray)
        XCTAssertNil(callback as? [String: Any])
    }

    func testRotatingPreviewDoesNotChangeTheCompletedPhotoCount() {
        let progress = TTProgressViewController.instantiate()
        progress.setPhotoProgress(completed: 2, total: 4)
        let count = progress.subtitleLabel.text
        for color in [UIColor.red, .green, .blue, .yellow, .red] {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { color.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
            progress.set(previewImage: image)
            XCTAssertEqual(progress.subtitleLabel.text, count)
        }
        progress.setPhotoProgress(completed: 3, total: 4)
        XCTAssertNotEqual(progress.subtitleLabel.text, count)
    }

    func testAggregatePreservesOrderedFailuresAndNestedNativePayloadOnJSONRoundTrip() throws {
        let native: [String: Any] = ["status": "SUCCESS", "petType": "DOG", "response": ["symptoms": [["code": "opacity", "polygons": [[12.25, 23.5, 35.75, 47.125]]]]]]
        let payload: [String: Any] = ["mode": "multi", "status": "PARTIAL", "photoCount": 2, "results": [
            ["photoId": "first", "photoIndex": 1, "status": "ERROR", "error": ["domain": "network", "code": 408, "message": "Try again", "retryable": true]],
            ["photoId": "second", "photoIndex": 2, "status": "SUCCESS", "result": native]
        ]]
        let original = AIScanResult(status: "PARTIAL", contractResult: payload)
        let decoded = try JSONDecoder().decode(AIScanResult.self, from: JSONEncoder().encode(original))
        XCTAssertTrue(decoded.isMultiMode)
        let photos = try XCTUnwrap(decoded.photoResults)
        XCTAssertEqual(photos.map(\.photoIndex), [1, 2])
        guard photos.count == 2 else { return }
        XCTAssertEqual(photos[0].error?.code, 408)
        XCTAssertEqual(photos[1].result?.jsonObject as NSDictionary?, native as NSDictionary)
        XCTAssertEqual(decoded.jsonArray as NSArray?, payload["results"] as? NSArray)
        XCTAssertNil(decoded.jsonObject)
    }
}

@MainActor
private final class MultiTestStackDismisser: AIScanCameraStackDismissing {
    func dismissStack(from camera: UIViewController, transition: AIScanCameraStackDismissalTransition, completion: @escaping () -> Void) { completion() }
}


@MainActor
private final class MultiCaptureCollectionProbe: AIScanCameraControllerDelegate {
    var inputs: [AISCImageInput] = []
    var preview: UIImage?
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error) { XCTFail("Unexpected collection failure: \(error)") }
    func aiscanCameraController(_ controller: AIScanCameraController, didCollect input: AISCImageInput, preview: UIImage) {
        inputs.append(input); self.preview = preview
    }
}

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

    private func addAttachment(_ attachment: XCTAttachment) { add(attachment) }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

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
        XCTAssertEqual(decoded.jsonObject as NSDictionary?, payload as NSDictionary)
    }
}

@MainActor
private final class MultiTestStackDismisser: AIScanCameraStackDismissing {
    func dismissStack(from camera: UIViewController, transition: AIScanCameraStackDismissalTransition, completion: @escaping () -> Void) { completion() }
}

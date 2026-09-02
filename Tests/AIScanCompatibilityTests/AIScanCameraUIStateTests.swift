import AVFoundation
import CoreImage
import SwiftUI
import UIKit
import WebKit
import XCTest
import AIScanCore
import AIScan
@_spi(AIScanLifecycle) @testable import AIScanCameraUI

private final class MockCameraEngine: NSObject, AISCCameraEngineControlling {
    weak var delegate: AISCCameraEngineDelegate?
    var automaticallyCapturesReadyFrames = false
    var analysisMode: AISCAnalysisMode { .onDevice }
    let captureSession = AVCaptureSession()

    private(set) var preparedContexts: [AISCScanContext] = []
    private(set) var configuredPositions: [AVCaptureDevice.Position] = []
    private(set) var configuredDisable4K: [Bool] = []
    private(set) var startRunningCount = 0
    private(set) var stopRunningCount = 0
    private(set) var torchStates: [Bool] = []
    private(set) var zoomFactors: [CGFloat] = []
    private(set) var zoomScales: [CGFloat] = []
    var torchError: Error?
    var cameraAccessGranted = true
    private(set) var cameraAccessRequestCount = 0
    private(set) var albumOpenCount = 0
    private(set) var albumCancelCount = 0
    private(set) var resultVisibleCount = 0
    private(set) var resultShareCount = 0
    private(set) var captureRequestCount = 0
    private(set) var diagnosedPhotoInputs: [AISCImageInput] = []
    private(set) var diagnosedPhotoImages: [CIImage] = []
    private(set) var submittedQuestionnaireAnswers: [[AISCQuestionnaireAnswer]] = []
    private(set) var resetCaptureAttemptCount = 0
    private(set) var resetCount = 0
    private(set) var cancelCount = 0
    var emitsPreparationProgress = true
    var completesPreparationImmediately = true
    private var pendingPreparationCompletions: [(Error?) -> Void] = []

    func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        cameraAccessRequestCount += 1
        completion(cameraAccessGranted)
    }

    func albumDidOpen() {
        albumOpenCount += 1
    }

    func albumDidCancel() {
        albumCancelCount += 1
    }

    func resultDidBecomeVisible() {
        resultVisibleCount += 1
    }

    func resultDidShare() {
        resultShareCount += 1
    }

    func prepare(with context: AISCScanContext, completion: @escaping (Error?) -> Void) {
        preparedContexts.append(context)
        completion(nil)
    }

    func prepare(
        with context: AISCScanContext,
        progress: ((Double) -> Void)?,
        completion: @escaping (Error?) -> Void
    ) {
        preparedContexts.append(context)
        if emitsPreparationProgress {
            progress?(0.25)
            progress?(1)
        }
        completion(nil)
    }

    func prepare(
        with context: AISCScanContext,
        detailedProgress: ((Double, Int64, Int64, Double) -> Void)?,
        completion: @escaping (Error?) -> Void
    ) {
        preparedContexts.append(context)
        if emitsPreparationProgress {
            detailedProgress?(0.25, 512, 2_048, 1_536)
            detailedProgress?(1, 2_048, 2_048, 4_096)
        }
        if completesPreparationImmediately {
            completion(nil)
        } else {
            pendingPreparationCompletions.append(completion)
        }
    }

    func completePendingPreparation(error: Error? = nil) {
        let completions = pendingPreparationCompletions
        pendingPreparationCompletions.removeAll()
        completions.forEach { $0(error) }
    }

    func configure(position: AVCaptureDevice.Position, disable4K: Bool) throws {
        configuredPositions.append(position)
        configuredDisable4K.append(disable4K)
    }

    func startRunning() {
        startRunningCount += 1
    }

    func stopRunning() {
        stopRunningCount += 1
    }

    func setTorchEnabled(_ enabled: Bool) throws {
        if let torchError {
            throw torchError
        }
        torchStates.append(enabled)
    }

    func setZoomFactor(_ factor: CGFloat) throws {
        zoomFactors.append(factor)
    }

    func scaleZoom(by scale: CGFloat) throws {
        zoomScales.append(scale)
    }

    func requestCapture() {
        captureRequestCount += 1
    }

    func diagnosePhoto(_ input: AISCImageInput) {
        diagnosedPhotoInputs.append(input)
    }

    func diagnosePhoto(_ image: CIImage) {
        diagnosedPhotoImages.append(image)
    }

    func submitQuestionnaireAnswers(_ answers: [AISCQuestionnaireAnswer]) {
        submittedQuestionnaireAnswers.append(answers)
    }

    func resetCaptureAttempt() {
        resetCaptureAttemptCount += 1
    }

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

    func emitPreview(_ preview: CIImage) {
        delegate?.cameraEngineDidAcceptPreviewImage?(preview)
    }

    func emitProgress(_ progress: Double) {
        delegate?.cameraEngineDidUpdateProgress(progress)
    }

    func emitQuestionnaire(_ questionnaire: AISCQuestionnaire) {
        delegate?.cameraEngineDidRequest?(questionnaire)
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
    private(set) var previewImage: UIImage?
    private(set) var questionnaire: AISCQuestionnaire?

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
        didCapturePreview image: UIImage
    ) {
        previewImage = image
        onEvent?("preview:\(Int(image.size.width))x\(Int(image.size.height))")
    }

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didUpdateDiagnosisProgress progress: Double
    ) {
        onEvent?("progress:\(progress)")
    }

    func aiscanCameraController(
        _ controller: AIScanCameraController,
        didRequest questionnaire: AISCQuestionnaire
    ) {
        self.questionnaire = questionnaire
        onEvent?("questionnaire:\(questionnaire.prompts.count)")
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

@MainActor
private final class MockCameraStackDismisser: AIScanCameraStackDismissing {
    private(set) var callCount = 0
    private(set) var didCompleteDismissal = false
    private(set) var hadPresentedController = false
    private(set) var transitions: [AIScanCameraStackDismissalTransition] = []

    func dismissStack(
        from camera: UIViewController,
        transition: AIScanCameraStackDismissalTransition,
        completion: @escaping () -> Void
    ) {
        callCount += 1
        transitions.append(transition)
        hadPresentedController = camera.presentedViewController != nil
        didCompleteDismissal = true
        completion()
    }
}

private final class MonotonicClockStub {
    var now: TimeInterval

    init(now: TimeInterval) {
        self.now = now
    }
}

@MainActor
private final class MockPopupDismisser: AIScanLegacyPopupDismissing {
    private(set) var callCount = 0
    private(set) var didCompleteDismissal = false

    func dismiss(
        _ container: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        callCount += 1
        didCompleteDismissal = true
        completion()
    }
}

@MainActor
private final class DeferredPopupDismisser: AIScanLegacyPopupDismissing {
    private(set) var callCount = 0

    func dismiss(
        _ container: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        callCount += 1
    }
}

@MainActor
private final class MockTransientSurfaceCoordinator: AIScanTransientSurfaceCoordinating {
    private(set) var dismissPresentedSurfaceCount = 0
    private(set) var dismissPopupCount = 0
    private(set) var presentedSurfaces: [UIViewController] = []

    func dismissPresentedSurface(
        from presenter: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        dismissPresentedSurfaceCount += 1
        completion()
    }

    func present(
        _ surface: UIViewController,
        from presenter: UIViewController,
        animated: Bool
    ) {
        presentedSurfaces.append(surface)
        surface.loadViewIfNeeded()
        surface.view.frame = presenter.view.bounds
        surface.view.layoutIfNeeded()
        surface.beginAppearanceTransition(true, animated: animated)
        surface.endAppearanceTransition()
    }

    func dismiss(
        _ container: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        dismissPopupCount += 1
        completion()
    }
}

final class AIScanCameraUIStateTests: XCTestCase {
    @available(iOS 14, *)
    @MainActor
    func testAlbumLoaderPreservesOriginalFilePixelDimensions() throws {
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 640, height: 480),
            format: UIGraphicsImageRendererFormat.default()
        )
        let source = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        }
        let data = try XCTUnwrap(source.pngData())
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try data.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let provider = try XCTUnwrap(NSItemProvider(contentsOf: fileURL))
        let loaded = expectation(description: "full-resolution album image loaded")
        var result: UIImage?
        AIScanAlbumImageLoader.loadFullResolutionImage(from: provider) { image in
            result = image
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)

        XCTAssertEqual(result?.cgImage?.width, source.cgImage?.width)
        XCTAssertEqual(result?.cgImage?.height, source.cgImage?.height)
    }
    func testContractStackTransitionFallsBackForAccessibilityAndInactiveRuntimeStates() {
        XCTAssertTrue(
            AIScanCameraStackTransitionPolicy.allowsCoordinatedTransition(
                duration: 0.2,
                animationsEnabled: true,
                reduceMotionEnabled: false,
                applicationIsActive: true,
                hasVisibleWindow: true
            )
        )

        for disabledEnvironment in [
            (0.0, true, false, true, true),
            (0.2, false, false, true, true),
            (0.2, true, true, true, true),
            (0.2, true, false, false, true),
            (0.2, true, false, true, false),
        ] {
            XCTAssertFalse(
                AIScanCameraStackTransitionPolicy.allowsCoordinatedTransition(
                    duration: disabledEnvironment.0,
                    animationsEnabled: disabledEnvironment.1,
                    reduceMotionEnabled: disabledEnvironment.2,
                    applicationIsActive: disabledEnvironment.3,
                    hasVisibleWindow: disabledEnvironment.4
                )
            )
        }
    }

    func testAlbumFrameRejectedShowsActionableGuidanceInsteadOfCriticalError() {
        let rejected = NSError(
            domain: AISCErrorDomain,
            code: AISCErrorCode.frameRejected.rawValue,
            userInfo: [AISCDisplayReasonKey: "더 가까이에서 촬영해 주세요"]
        )

        XCTAssertEqual(
            AIScanCameraStrings.displayMessage(for: rejected, languageCode: "ko"),
            "더 가까이에서 촬영해 주세요"
        )
        XCTAssertEqual(
            AIScanCameraStrings.displayMessage(for: rejected, languageCode: "en"),
            "Please capture from closer."
        )
    }

    func testCameraFrameRejectedRestoresOriginalLocalizedCaptureGuidance() {
        func message(_ reason: String, languageCode: String = "en") -> String {
            let rejected = NSError(
                domain: AISCErrorDomain,
                code: AISCErrorCode.frameRejected.rawValue,
                userInfo: [AISCDisplayReasonKey: reason]
            )
            return AIScanCameraStrings.displayMessage(
                for: rejected,
                languageCode: languageCode
            )
        }

        let englishCases = [
            ("눈을 촬영해 주세요.", "Please capture the eye."),
            ("치아를 촬영해 주세요.", "Please capture the dental."),
            ("귀를 촬영해 주세요.", "Please capture the ear."),
            ("몸통을 촬영해 주세요.", "Please capture the body."),
            ("발을 촬영해 주세요.", "Please capture the paw."),
            ("피부를 촬영해 주세요.", "Please capture the skin."),
            ("초점을 잘 맞춰 주세요.", "Please adjust the focus."),
            ("더 가까이에서 촬영해 주세요", "Please capture from closer."),
            ("더 멀리서 촬영해 주세요", "Please capture from farther."),
        ]
        for (reason, expected) in englishCases {
            XCTAssertEqual(message(reason), expected)
        }

        XCTAssertEqual(
            message("눈을 촬영해 주세요.", languageCode: "ja"),
            "目を撮影してください。"
        )
    }

    func testAlbumFrameRejectedRestoresOriginalAlbumSpecificCopy() {
        func rejected(_ reason: String) -> NSError {
            NSError(
                domain: AISCErrorDomain,
                code: AISCErrorCode.frameRejected.rawValue,
                userInfo: [AISCDisplayReasonKey: reason]
            )
        }

        let cases: [(String, AISCPartType, String?, String)] = [
            ("눈을 촬영해 주세요.", .eye, nil, "눈이 잘 보이는 사진을 선택해 주세요."),
            ("치아를 촬영해 주세요.", .teeth, nil, "치아가 잘 보이는 사진을 선택해 주세요."),
            ("초점을 잘 맞춰 주세요.", .eye, nil, "초점이 잘 맞는 선명한 사진을 선택해 주세요."),
            ("더 가까이에서 촬영해 주세요", .eye, nil, "피사체가 더 크게 나온 사진을 선택해 주세요."),
            ("더 멀리서 촬영해 주세요", .eye, nil, "피사체가 눈에 다 들어오는 사진을 선택해 주세요."),
            ("귀를 촬영해 주세요.", .skin, "ear", "귀가 잘 보이는 사진을 선택해 주세요."),
            ("몸통을 촬영해 주세요.", .skin, "belly", "몸통이 잘 보이는 사진을 선택해 주세요."),
            ("발을 촬영해 주세요.", .skin, "foot", "발이 잘 보이는 사진을 선택해 주세요."),
        ]

        for (reason, partType, position, expected) in cases {
            XCTAssertEqual(
                AIScanCameraStrings.albumDisplayMessage(
                    for: rejected(reason),
                    partType: partType,
                    analysisPosition: position,
                    languageCode: "ko"
                ),
                expected
            )
        }

        XCTAssertEqual(
            AIScanCameraStrings.albumDisplayMessage(
                for: rejected("눈을 촬영해 주세요."),
                partType: .eye,
                analysisPosition: nil,
                languageCode: "en"
            ),
            "Please select a photo where the eye is clearly visible."
        )
    }

    @MainActor
    func testAlbumRejectsImagesBelowOriginalOneHundredPointResolutionGate() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }

        XCTAssertThrowsError(try controller.diagnosePhoto(image)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, AISCErrorDomain)
            XCTAssertEqual(nsError.code, AISCErrorCode.invalidInput.rawValue)
            XCTAssertEqual(
                nsError.userInfo[AISCDisplayReasonKey] as? String,
                "해상도가 너무 낮습니다. 더 선명한 사진으로 시도해 주세요."
            )
        }
        XCTAssertTrue(engine.diagnosedPhotoImages.isEmpty)
    }

    @MainActor
    func testQuestionnaireRequestAndAnswersCrossOnlyTheNarrowCoreBoundary() async throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let probe = CameraEventProbe()
        controller.delegate = probe
        let prompts = [
            AISCQuestionnairePrompt(identifier: "q1", text: "첫 번째 질문"),
            AISCQuestionnairePrompt(identifier: "q2", text: "두 번째 질문"),
        ]
        let questionnaire = AISCQuestionnaire(prompts: prompts)

        engine.emitQuestionnaire(questionnaire)
        for _ in 0..<20 where probe.questionnaire == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(probe.questionnaire?.prompts.map(\.identifier), ["q1", "q2"])
        controller.submitQuestionnaireAnswers([
            AISCQuestionnaireAnswer(prompt: prompts[0], positive: false),
            AISCQuestionnaireAnswer(prompt: prompts[1], positive: true),
        ])
        XCTAssertEqual(engine.submittedQuestionnaireAnswers.count, 1)
        XCTAssertEqual(
            engine.submittedQuestionnaireAnswers[0].map(\.positive),
            [false, true]
        )
    }

    @MainActor
    func testQuestionnaireViewModelSupportsBackNavigationAndAnswerReplacement() {
        let prompts = [
            AISCQuestionnairePrompt(identifier: "q1", text: "첫 번째 질문"),
            AISCQuestionnairePrompt(identifier: "q2", text: "두 번째 질문"),
        ]
        var completedAnswers: [AISCQuestionnaireAnswer] = []
        let viewModel = AIScanQuestionnaireViewModel(prompts: prompts) {
            completedAnswers = $0
        }

        viewModel.answerCurrentQuestion(positive: false)
        XCTAssertEqual(viewModel.currentIndex, 1)
        viewModel.moveBack()
        XCTAssertEqual(viewModel.currentIndex, 0)
        viewModel.answerCurrentQuestion(positive: true)
        viewModel.answerCurrentQuestion(positive: false)

        XCTAssertTrue(viewModel.isSubmitting)
        XCTAssertEqual(completedAnswers.map(\.prompt.identifier), ["q1", "q2"])
        XCTAssertEqual(completedAnswers.map(\.positive), [true, false])
    }

    @MainActor
    func testQuestionnaireKeepsItsOriginalContentDuringFinalSubmission() {
        let prompt = AISCQuestionnairePrompt(
            identifier: "q1",
            text: "최근 눈물을 자주 흘리나요?"
        )
        let viewModel = AIScanQuestionnaireViewModel(prompts: [prompt]) { _ in }

        XCTAssertEqual(viewModel.presentationState, .answering)
        viewModel.answerCurrentQuestion(positive: false)

        XCTAssertEqual(viewModel.presentationState, .submitting)
    }

    @MainActor
    func testCameraShowsQuestionnaireOverProgressAndRemovesItAfterSubmission() async throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        context.questionnaireEnabled = true
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context
        )
        camera.beginsScanningAutomatically = false
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        camera.aiscanCameraController(
            controller,
            didCapture: makeEvaluation(captureAllowed: true)
        )
        let prompts = [
            AISCQuestionnairePrompt(identifier: "q1", text: "첫 번째 질문"),
            AISCQuestionnairePrompt(identifier: "q2", text: "두 번째 질문"),
        ]
        camera.aiscanCameraController(
            controller,
            didRequest: AISCQuestionnaire(prompts: prompts)
        )

        var host: UIHostingController<AIScanQuestionnaireView>?
        for _ in 0..<20 where host == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
            host = camera.presentedViewController?.children.compactMap {
                $0 as? UIHostingController<AIScanQuestionnaireView>
            }.first
        }

        let questionnaireHost = try XCTUnwrap(host)
        XCTAssertEqual(
            questionnaireHost.view.accessibilityIdentifier,
            "aiscan.questionnaire"
        )
        questionnaireHost.rootView.viewModel.answerCurrentQuestion(positive: false)
        questionnaireHost.rootView.viewModel.answerCurrentQuestion(positive: true)

        XCTAssertEqual(engine.submittedQuestionnaireAnswers.count, 1)
        XCTAssertEqual(
            engine.submittedQuestionnaireAnswers[0].map(\.positive),
            [false, true]
        )
        XCTAssertFalse(
            camera.presentedViewController?.children.contains {
                $0 is UIHostingController<AIScanQuestionnaireView>
            } ?? true
        )
        XCTAssertEqual(
            camera.presentedViewController?.view.accessibilityIdentifier,
            "aiscan.camera.progress"
        )
    }

    @MainActor
    func testQuestionnaireVisualParityArtifacts() {
        let prompts = [
            AISCQuestionnairePrompt(
                identifier: "q1",
                text: "최근 눈물을 자주 흘리거나 눈 주변이 젖어 있나요?"
            ),
            AISCQuestionnairePrompt(identifier: "q2", text: "눈을 자주 비비나요?"),
        ]

        for (style, suffix) in [
            (UIUserInterfaceStyle.light, "light"),
            (.dark, "dark"),
        ] {
            let viewModel = AIScanQuestionnaireViewModel(prompts: prompts) { _ in }
            let view = AIScanQuestionnaireView(viewModel: viewModel)
                .environment(\.colorScheme, style == .dark ? .dark : .light)
            let host = UIHostingController(rootView: view)
            host.overrideUserInterfaceStyle = style
            let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            let window = UIWindow(frame: frame)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.loadViewIfNeeded()
            host.view.frame = frame
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(
                bounds: host.view.bounds,
                format: format
            ).image { context in
                host.view.layer.render(in: context.cgContext)
            }
            XCTAssertGreaterThan(image.pngData()?.count ?? 0, 1_000)
            let attachment = XCTAttachment(image: image)
            attachment.name = "gap_zero_questionnaire_\(suffix)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
        }
    }

    @MainActor
    func testHighLevelManagerDisablesOptionalSurfacesByDefaultAndCanEnableThem() throws {
        AIScanManager.configure(publishableKey: "pk_test_questionnaire")
        defer { AIScanManager.clearConfiguration() }

        let defaultCamera = try AIScanManager.makeCameraViewController(
            petType: .dog,
            partType: .eye
        ) as! AIScanCameraViewController
        let enabledCamera = try AIScanManager.makeCameraViewController(
            petType: .dog,
            partType: .eye,
            enablesQuestionnaire: true,
            allowsAlbum: true
        ) as! AIScanCameraViewController

        XCTAssertFalse(defaultCamera.scanContext.questionnaireEnabled)
        XCTAssertTrue(enabledCamera.scanContext.questionnaireEnabled)
        XCTAssertEqual(
            Mirror(reflecting: defaultCamera).descendant("allowsAlbum") as? Bool,
            false
        )
        XCTAssertEqual(
            Mirror(reflecting: enabledCamera).descendant("allowsAlbum") as? Bool,
            true
        )
    }

    @MainActor
    func testDisabledQuestionnaireIgnoresAnUnexpectedCoreRequest() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        context.questionnaireEnabled = false
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context
        )
        camera.beginsScanningAutomatically = false
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        camera.aiscanCameraController(
            controller,
            didCapture: makeEvaluation(captureAllowed: true)
        )
        camera.aiscanCameraController(
            controller,
            didRequest: AISCQuestionnaire(prompts: [
                AISCQuestionnairePrompt(identifier: "q1", text: "Should stay hidden"),
            ])
        )

        let questionnaireValue = Mirror(reflecting: camera).children.first {
            $0.label == "questionnaireController"
        }?.value
        let questionnaireController = questionnaireValue.flatMap {
            Mirror(reflecting: $0).children.first?.value as? UIViewController
        }
        XCTAssertNil(questionnaireController)
        XCTAssertFalse(
            camera.children.contains { $0 is UIHostingController<AIScanQuestionnaireView> }
        )
    }

    @MainActor
    func testDeniedCameraPermissionOpensSettingsAndRechecksOnAppReturn() async throws {
        let engine = MockCameraEngine()
        engine.cameraAccessGranted = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        var settingsOpenCount = 0
        let transientCoordinator = MockTransientSurfaceCoordinator()
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: MockCameraStackDismisser(),
            transientSurfaceCoordinator: transientCoordinator,
            settingsOpener: { settingsOpenCount += 1 }
        )

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        var settingsButton: UIButton?
        for _ in 0..<20 where settingsButton == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
            settingsButton = camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.settings"
            ) as? UIButton
        }

        let button = try XCTUnwrap(settingsButton)
        XCTAssertEqual(button.title(for: .normal), AIScanCameraStrings.localized(.settings))
        XCTAssertEqual(engine.cameraAccessRequestCount, 1)
        XCTAssertNil(
            camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.retry"
            )
        )

        try await Task.sleep(nanoseconds: 500_000_000)
        let permissionPopup = try XCTUnwrap(
            camera.presentedViewController?.children
                .compactMap { $0 as? TTPopupAlertViewController }
                .first
        )
        permissionPopup.confirm(button)
        for _ in 0..<20 where settingsOpenCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(settingsOpenCount, 1)

        engine.cameraAccessGranted = true
        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        for _ in 0..<20 where engine.configuredPositions.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(engine.cameraAccessRequestCount, 2)
        XCTAssertEqual(engine.preparedContexts.count, 1)
        XCTAssertEqual(engine.configuredPositions, [.back])
    }

    @MainActor
    func testBackgroundCancelsCaptureAndResumesOnlyThePreparedCamera() async throws {
        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        context.displayMetadata = ["show_flash_warning": "false"]
        let camera = AIScanCameraViewController(cameraController: controller, context: context)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        for _ in 0..<20 where engine.startRunningCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(engine.startRunningCount, 1)

        camera.beginCaptureAttempt()
        XCTAssertTrue(engine.automaticallyCapturesReadyFrames)

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        XCTAssertFalse(engine.automaticallyCapturesReadyFrames)
        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)
        XCTAssertEqual(engine.stopRunningCount, 1)

        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        XCTAssertEqual(engine.startRunningCount, 2)
    }

    @MainActor
    func testPreparationFinishingInBackgroundDefersCameraStartUntilForeground() async throws {
        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        engine.completesPreparationImmediately = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        context.displayMetadata = ["show_flash_warning": "false"]
        let camera = AIScanCameraViewController(cameraController: controller, context: context)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        for _ in 0..<20 where engine.preparedContexts.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(engine.preparedContexts.count, 1)

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        engine.completePendingPreparation()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(engine.configuredPositions, [.back])
        XCTAssertEqual(
            engine.startRunningCount,
            0,
            "A preparation callback must not start AVCaptureSession while the app is backgrounded"
        )

        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        XCTAssertEqual(engine.startRunningCount, 1)
    }

    @MainActor
    func testForegroundDoesNotRestartCameraThatWasAlreadyStoppedForDiagnosis() async throws {
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

        camera.beginCaptureAttempt()
        engine.emitCapture(makeEvaluation(captureAllowed: true))
        for _ in 0..<20 where engine.stopRunningCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(engine.stopRunningCount, 1)

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        XCTAssertEqual(engine.startRunningCount, 0)
    }

    @MainActor
    func testLegacyStoryboardImagesResolveFromPublicResourceBundle() {
        let requiredImages = [
            "001CommonNewlogo",
            "checkResultEyeImgNo",
            "commonToggleToggleOff",
            "illustLoadingDog",
        ]

        for name in requiredImages {
            XCTAssertNotNil(
                UIImage(
                    named: name,
                    in: AIScanCameraResourceBundle.bundle,
                    compatibleWith: nil
                ),
                "Missing original storyboard image: \(name)"
            )
        }
    }

    @MainActor
    func testCameraAndPreviewGuideReplaceStoryboardKoreanWithOriginalLocalizedCopy() {
        let camera = CameraViewController.instantiate(partType: .eye)
        camera.loadViewIfNeeded()
        camera.applyLocalizedCopy(languageCode: "en")

        XCTAssertTrue(camera.guideContainer.allLabels.contains { $0.text == "User guide" })
        XCTAssertFalse(camera.guideContainer.allLabels.contains { $0.text == "촬영가이드" })

        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let previewGuide = PreviewGuideViewController.instantiate(context: context)
        previewGuide.loadViewIfNeeded()
        previewGuide.applyLocalizedCopy(languageCode: "ja")

        let texts = previewGuide.view.allLabels.compactMap(\.text)
        XCTAssertTrue(texts.contains("撮影例です。"))
        XCTAssertFalse(texts.contains("잘 보고 따라해주세요"))
        XCTAssertFalse(texts.contains("촬영 예시 화면입니다."))
    }

    @MainActor
    func testResultHTMLKeepsSystemTypographyAndBoldEmphasisInEveryLanguage() throws {
        let cell = try XCTUnwrap(
            UINib(
                nibName: "ResultItemCell",
                bundle: AIScanReferenceStrings.resourceBundle
            ).instantiate(withOwner: nil).first as? AIScanResultItemCell
        )
        cell.configure(
            symptom: AIScanDisplaySymptomViewModel(
                id: "typography",
                code: "typography",
                name: "Typography",
                detailRows: [
                    AIScanDisplayDetailRowViewModel(
                        text: "<b>Heading</b><br>Body copy",
                        iconName: nil
                    )
                ]
            )
        )

        let label = try XCTUnwrap(
            cell.contentView.allLabels.first {
                $0.attributedText?.string.contains("Heading") == true
            }
        )
        let attributed = try XCTUnwrap(label.attributedText)
        let headingRange = (attributed.string as NSString).range(of: "Heading")
        let bodyRange = (attributed.string as NSString).range(of: "Body copy")
        let headingFont = try XCTUnwrap(
            attributed.attribute(.font, at: headingRange.location, effectiveRange: nil) as? UIFont
        )
        let bodyFont = try XCTUnwrap(
            attributed.attribute(.font, at: bodyRange.location, effectiveRange: nil) as? UIFont
        )

        XCTAssertEqual(bodyFont.familyName, UIFont.systemFont(ofSize: 14).familyName)
        XCTAssertEqual(bodyFont.pointSize, 14, accuracy: 0.1)
        XCTAssertTrue(headingFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertEqual(headingFont.familyName, bodyFont.familyName)
    }

    @MainActor
    func testCameraFlowIsLockedToPortrait() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let camera = AIScanCameraViewController(cameraController: controller, context: context)

        XCTAssertFalse(camera.shouldAutorotate)
        XCTAssertEqual(camera.supportedInterfaceOrientations, .portrait)
        XCTAssertEqual(camera.preferredInterfaceOrientationForPresentation, .portrait)
        XCTAssertEqual(camera.captureAttemptDuration, 60)
    }

    @MainActor
    func testPublicCameraAdapterDelegatesCameraOwnershipToPrivateCore() throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)

        XCTAssertTrue(controller.captureSession === engine.captureSession)

        try controller.configure(position: .back)
        controller.startRunning()
        controller.stopRunning()
        try controller.setTorchEnabled(true)
        try controller.setZoomFactor(2)
        try controller.scaleZoom(by: 1.5)
        controller.resetCaptureAttempt()

        XCTAssertEqual(engine.configuredPositions, [.back])
        XCTAssertEqual(
            engine.configuredDisable4K,
            [false],
            "Core normalizes bbox thresholds to 1080p while camera capture retains 4K quality."
        )
        XCTAssertEqual(engine.startRunningCount, 1)
        XCTAssertEqual(engine.stopRunningCount, 1)
        XCTAssertEqual(engine.torchStates, [true])
        XCTAssertEqual(engine.zoomFactors, [2])
        XCTAssertEqual(engine.zoomScales, [1.5])
        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)
    }

    @MainActor
    func testAlbumPhotoAdapterForwardsAnUprightImageToPrivateCore() throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 137, height: 123),
            format: format
        ).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 137, height: 123))
        }

        try controller.diagnosePhoto(image)

        let coreImage = try XCTUnwrap(engine.diagnosedPhotoImages.first)
        XCTAssertEqual(coreImage.extent.width, 137)
        XCTAssertEqual(coreImage.extent.height, 123)
        XCTAssertTrue(engine.diagnosedPhotoInputs.isEmpty)
    }

    @MainActor
    func testAlbumPhotoAdapterNormalizesUIImageOrientationBeforePrivateCore() throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 240, height: 140),
            format: format
        ).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 140))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 120, y: 0, width: 120, height: 140))
        }
        let sourceCGImage = try XCTUnwrap(source.cgImage)
        let oriented = UIImage(cgImage: sourceCGImage, scale: 1, orientation: .right)

        try controller.diagnosePhoto(oriented)

        let coreImage = try XCTUnwrap(engine.diagnosedPhotoImages.first)
        XCTAssertEqual(coreImage.extent.width, 140)
        XCTAssertEqual(coreImage.extent.height, 240)
    }

    func testCaptureAttemptTimesOutExactlyOnceAtSixtySeconds() {
        let startedAt: TimeInterval = 1_000
        var state = AIScanCaptureAttemptState()

        state.begin(at: startedAt)

        guard case let .progress(progress) = state.update(
            at: startedAt + 59.999,
            duration: 60
        ) else {
            return XCTFail("The attempt timed out before sixty seconds.")
        }
        XCTAssertEqual(progress, 59.999 / 60, accuracy: 0.000_001)
        XCTAssertEqual(
            state.update(at: startedAt + 60, duration: 60),
            .timedOut
        )
        XCTAssertEqual(
            state.update(at: startedAt + 61, duration: 60),
            .inactive
        )
        XCTAssertFalse(state.isActive)
    }

    func testCaptureAttemptRetryStartsACompletelyNewTimeoutWindow() {
        let firstStart: TimeInterval = 2_000
        let retryStart = firstStart + 75
        var state = AIScanCaptureAttemptState()

        state.begin(at: firstStart)
        XCTAssertEqual(
            state.update(at: firstStart + 60, duration: 60),
            .timedOut
        )

        state.begin(at: retryStart)

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(
            state.update(at: retryStart + 30, duration: 60),
            .progress(0.5)
        )
        XCTAssertEqual(
            state.update(at: retryStart + 60, duration: 60),
            .timedOut
        )
    }

    func testCaptureAttemptCancelClearsThePreviousDeadline() {
        let startedAt: TimeInterval = 3_000
        var state = AIScanCaptureAttemptState()

        state.begin(at: startedAt)
        state.cancel()

        XCTAssertFalse(state.isActive)
        XCTAssertEqual(
            state.update(at: startedAt + 60, duration: 60),
            .inactive
        )
    }

    func testCaptureAttemptStateTransitionTableRejectsOutOfOrderEvents() {
        var state = AIScanCaptureAttemptState()

        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.markDiagnosing())
        XCTAssertTrue(state.begin(at: 100))
        XCTAssertEqual(state.phase, .capturing)
        XCTAssertFalse(state.begin(at: 101))
        XCTAssertTrue(state.markDiagnosing())
        XCTAssertEqual(state.phase, .diagnosing)
        XCTAssertEqual(state.update(at: 200, duration: 60), .inactive)
        XCTAssertFalse(state.markDiagnosing())

        XCTAssertTrue(state.markCompleted())
        XCTAssertEqual(state.phase, .completed)
        XCTAssertFalse(state.markCompleted())
        XCTAssertFalse(state.begin(at: 300))
        XCTAssertFalse(state.prepareForRetry())
        XCTAssertEqual(state.phase, .completed)

        var failedState = AIScanCaptureAttemptState()
        XCTAssertTrue(failedState.begin(at: 400))
        XCTAssertTrue(failedState.markFailed())
        XCTAssertEqual(failedState.phase, .failed)
        XCTAssertFalse(failedState.markFailed())

        XCTAssertTrue(failedState.prepareForRetry())
        XCTAssertTrue(failedState.begin(at: 500))
        failedState.cancel()
        XCTAssertEqual(failedState.phase, .cancelled)
        XCTAssertTrue(failedState.begin(at: 600))
        XCTAssertEqual(failedState.phase, .capturing)
    }

    func testPreprocessRetakeReturnsDiagnosingAttemptToRetryableState() {
        var state = AIScanCaptureAttemptState()

        XCTAssertTrue(state.begin(at: 1))
        XCTAssertTrue(state.markDiagnosing())
        XCTAssertTrue(state.markNeedsRetake())
        XCTAssertEqual(state.phase, .failed)
        XCTAssertTrue(state.prepareForRetry())
        XCTAssertEqual(state.phase, .idle)
    }

    @MainActor
    func testRepeatedActiveCaptureControllersReleaseTheirTimerDelegateAndCoreSession() async {
        for cycle in 0..<20 {
            let engine = MockCameraEngine()
            weak var releasedCamera: AIScanCameraViewController?

            autoreleasepool {
                let controller = AIScanCameraController(cameraEngine: engine)
                let context = AISCScanContext()
                context.petType = .dog
                context.partType = .eye
                let camera = AIScanCameraViewController(
                    cameraController: controller,
                    context: context
                )
                camera.beginsScanningAutomatically = false
                camera.loadViewIfNeeded()
                camera.beginCaptureAttempt()
                releasedCamera = camera
            }

            await Task.yield()
            XCTAssertNil(releasedCamera, "camera leaked on repeated cycle \(cycle)")
            XCTAssertNil(engine.delegate, "Core delegate leaked on repeated cycle \(cycle)")
            XCTAssertEqual(engine.cancelCount, 1, "Core cancel mismatch on cycle \(cycle)")
        }
    }

    @MainActor
    func testCameraTimeoutResetsCoreAndPresentsOnlyOnce() throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let clock = MonotonicClockStub(now: 10_000)
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: MockCameraStackDismisser(),
            monotonicTime: { clock.now }
        )
        camera.beginsScanningAutomatically = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        clock.now += 60
        camera.updateCaptureAttemptTimer()
        camera.updateCaptureAttemptTimer()

        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)
        XCTAssertEqual(engine.resetCount, 0)
        XCTAssertFalse(engine.automaticallyCapturesReadyFrames)
        XCTAssertNotNil(
            camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.timeover"
            )
        )
    }

    @MainActor
    func testCameraTimeoutRetryStartsANewFullSixtySecondWindow() async throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let clock = MonotonicClockStub(now: 30_000)
        let surfaceCoordinator = MockTransientSurfaceCoordinator()
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: MockCameraStackDismisser(),
            transientSurfaceCoordinator: surfaceCoordinator,
            monotonicTime: { clock.now }
        )
        camera.beginsScanningAutomatically = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        clock.now += 60
        camera.updateCaptureAttemptTimer()

        let timeoutContainer = try XCTUnwrap(surfaceCoordinator.presentedSurfaces.last)
        let popup = try XCTUnwrap(
            timeoutContainer.children.first as? TTPopupTimeoverViewController
        )
        popup.confirm(popup.confirmButton as Any)
        for _ in 0..<20 where surfaceCoordinator.dismissPopupCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(surfaceCoordinator.dismissPopupCount, 1)
        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)
        XCTAssertTrue(engine.automaticallyCapturesReadyFrames)

        clock.now += 59.999
        camera.updateCaptureAttemptTimer()
        XCTAssertEqual(surfaceCoordinator.presentedSurfaces.count, 1)
        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)

        clock.now += 0.001
        camera.updateCaptureAttemptTimer()
        XCTAssertEqual(engine.resetCaptureAttemptCount, 2)
        XCTAssertEqual(surfaceCoordinator.presentedSurfaces.count, 2)
        XCTAssertNotNil(
            surfaceCoordinator.presentedSurfaces.last?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.timeover"
            )
        )
    }

    @MainActor
    func testCameraCaptureCancelClearsTheDeadlineAndResetsCoreOnce() throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let clock = MonotonicClockStub(now: 40_000)
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: MockCameraStackDismisser(),
            monotonicTime: { clock.now }
        )
        camera.beginsScanningAutomatically = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertFalse(engine.automaticallyCapturesReadyFrames)
        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)
        clock.now += 60
        camera.updateCaptureAttemptTimer()
        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)
        XCTAssertNil(camera.presentedViewController)
    }

    @MainActor
    func testCaptureDeliveredAfterTimeoutCannotReplaceTheTimeoutPopup() throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let clock = MonotonicClockStub(now: 20_000)
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: MockCameraStackDismisser(),
            monotonicTime: { clock.now }
        )
        camera.beginsScanningAutomatically = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        clock.now += 60
        camera.updateCaptureAttemptTimer()
        let timeoutPopup = try XCTUnwrap(camera.presentedViewController)

        camera.aiscanCameraController(
            controller,
            didCapture: makeEvaluation(captureAllowed: true)
        )

        XCTAssertTrue(camera.presentedViewController === timeoutPopup)
        XCTAssertNotNil(
            timeoutPopup.view.descendant(
                accessibilityIdentifier: "aiscan.camera.timeover"
            )
        )
    }

    @MainActor
    func testOriginalFlashWarningCopyAndStylingAreRestored() throws {
        let popup = TTFlashWarningAlertViewController.instantiate(
            showsSkinGuidance: true,
            startsWithFlash: false,
            onStart: { _ in }
        )
        popup.loadViewIfNeeded()

        XCTAssertEqual(popup.titleLabel.text, AIScanCameraStrings.localized(.flashTitle))
        XCTAssertEqual(
            popup.subtitleLabel.text,
            AIScanCameraStrings.localized(.flashSubtitle)
        )
        XCTAssertEqual(
            popup.flashWarningLabel.text,
            AIScanCameraStrings.localized(.flashBenefit)
        )
        XCTAssertTrue(popup.flashWarningLabel.attributedText?.length ?? 0 > 0)
        XCTAssertFalse(popup.skinContainer.isHidden)
        XCTAssertEqual(popup.confirmButton.title(for: .normal), AIScanCameraStrings.localized(.start))
        XCTAssertEqual(
            AIScanCameraStrings.localized(.flashTitle, languageCode: "ko"),
            "플래시 사용을 권장해요"
        )
        XCTAssertEqual(
            AIScanCameraStrings.localized(.flashSubtitle, languageCode: "ko"),
            "일시적인 플래시 활성화가 동물에게 불편함을 유발할 순 있지만 건강상 위해를 미친다는 과학적 근거는 없어요. 불편함이 우려되면 플래시 입구에 얇은 종이를 덧대어주시면 도움이 될 수 있어요."
        )
    }

    @MainActor
    func testTimeoverRetryDismissesThePopupContainerBeforeRunningItsAction() async {
        let dismisser = MockPopupDismisser()
        var actionCount = 0
        let popup = TTPopupTimeoverViewController.instantiate(
            onRetry: {
                XCTAssertTrue(dismisser.didCompleteDismissal)
                actionCount += 1
            },
            onGuide: {}
        )
        let container = AIScanLegacyPopupContainer(
            content: popup,
            popupDismisser: dismisser
        )

        container.loadViewIfNeeded()
        popup.loadViewIfNeeded()
        popup.confirm(popup.confirmButton as Any)

        for _ in 0..<10 where dismisser.callCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(dismisser.callCount, 1)
        XCTAssertEqual(actionCount, 1)
    }

    @MainActor
    func testBottomRetakePopupStartsOffscreenBeforeItsFirstVisibleFrame() {
        let popup = TTPopupCheckedResultViewController.instantiate(
            item: AIScanRetakeGuideItem(
                title: "Hold still",
                wrongTitle: "Wrong",
                rightTitle: "Right",
                wrongImage: nil,
                rightImage: nil
            ),
            onRetake: {}
        )
        let container = AIScanLegacyBottomPopupContainer(content: popup)

        container.loadViewIfNeeded()
        XCTAssertEqual(popup.view.transform.ty, 363, accuracy: 0.5)

        container.beginAppearanceTransition(true, animated: false)
        container.endAppearanceTransition()
        XCTAssertEqual(popup.view.transform, .identity)
    }

    @MainActor
    func testPopupCardKeepsSafeMarginsOnAnIPhoneSEWidth() {
        let popup = TTPopupAlertViewController.instantiate(
            title: "Notice",
            subtitle: String(repeating: "Long localized content ", count: 12),
            primaryTitle: "Close",
            secondaryTitle: nil,
            onPrimary: nil,
            onSecondary: nil
        )
        let container = AIScanLegacyPopupContainer(content: popup)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        window.rootViewController = container
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        container.loadViewIfNeeded()
        container.view.frame = window.bounds
        container.view.setNeedsLayout()
        container.view.layoutIfNeeded()

        XCTAssertGreaterThanOrEqual(popup.view.frame.minX, 16)
        XCTAssertLessThanOrEqual(popup.view.frame.maxX, 304)
        XCTAssertGreaterThan(popup.view.frame.height, 0)
        XCTAssertLessThanOrEqual(popup.view.frame.height, 536)
        XCTAssertFalse(popup.view.hasAmbiguousLayout)
        XCTAssertLessThanOrEqual(popup.subtitleLabel.frame.maxY, popup.view.bounds.maxY)
    }

    @MainActor
    func testEveryPopupCardRestoresTheOriginalThirtyThreePointCorners() {
        let popups: [UIViewController] = [
            TTFlashWarningAlertViewController.instantiate(
                showsSkinGuidance: false,
                startsWithFlash: false,
                onStart: { _ in }
            ),
            TTPopupTimeoverViewController.instantiate(
                onRetry: {},
                onGuide: {}
            ),
            TTPopupSelectedSkinViewController.instantiate(
                onStart: { _, _ in },
                onClose: {}
            ),
        ]

        for popup in popups {
            let container = AIScanLegacyPopupContainer(content: popup)
            container.loadViewIfNeeded()
            popup.loadViewIfNeeded()

            XCTAssertEqual(popup.view.layer.cornerRadius, 33)
            XCTAssertTrue(popup.view.layer.masksToBounds)
        }
    }

    @MainActor
    func testSkinSelectionContainerUsesOriginalTwentyPointCorners() {
        let popup = TTPopupSelectedSkinViewController.instantiate(
            onStart: { _, _ in },
            onClose: {}
        )
        let container = AIScanLegacyPopupContainer(
            content: popup,
            cardWidth: 316,
            cardCornerRadius: 20,
            presentationSpringDamping: 0.75
        )
        container.loadViewIfNeeded()

        XCTAssertEqual(popup.view.layer.cornerRadius, 20)
        XCTAssertTrue(popup.view.layer.masksToBounds)
    }

    @MainActor
    func testEveryOriginalPopupUsesReadableSemanticColorsInDarkMode() throws {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let popups: [UIViewController] = [
            TTPopupAlertViewController.instantiate(
                title: "Notice",
                subtitle: "Camera access is required.",
                primaryTitle: "Settings",
                secondaryTitle: "Close",
                onPrimary: nil,
                onSecondary: nil
            ),
            TTFlashWarningAlertViewController.instantiate(
                showsSkinGuidance: true,
                startsWithFlash: false,
                onStart: { _ in }
            ),
            TTPopupTimeoverViewController.instantiate(
                onRetry: {},
                onGuide: {}
            ),
            TTPopupSelectedSkinViewController.instantiate(
                initialPosition: "ear",
                onStart: { _, _ in },
                onClose: {}
            ),
        ]

        for popup in popups {
            popup.overrideUserInterfaceStyle = .dark
            popup.loadViewIfNeeded()
            for label in popup.view.allLabels where label.text?.isEmpty == false {
                let renderedColor = try XCTUnwrap(
                    label.attributedText
                        .flatMap { $0.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor }
                        ?? label.textColor
                )
                XCTAssertNotEqual(
                    renderedColor.resolvedColor(with: darkTraits),
                    UIColor.black,
                    "\(type(of: popup)) rendered unreadable black text in dark mode."
                )
            }
        }

        let expectedPrimaryText = UIColor.label.resolvedColor(with: darkTraits)
        for label in [
            (popups[0] as? TTPopupAlertViewController)?.titleLabel,
            (popups[1] as? TTFlashWarningAlertViewController)?.titleLabel,
            (popups[2] as? TTPopupTimeoverViewController)?.titleLabel,
            (popups[3] as? TTPopupSelectedSkinViewController)?.titleLabel,
        ].compactMap({ $0 }) {
            let renderedColor = try XCTUnwrap(
                label.attributedText
                    .flatMap { $0.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor }
                    ?? label.textColor
            )
            XCTAssertEqual(renderedColor.resolvedColor(with: darkTraits), expectedPrimaryText)
        }

        let expectedPrimaryAction = try XCTUnwrap(
            UIColor(
                named: "AISBrandPrimary",
                in: AIScanCameraResourceBundle.bundle,
                compatibleWith: darkTraits
            )
        ).resolvedColor(with: darkTraits)
        let primaryButtons = [
            (popups[0] as? TTPopupAlertViewController)?.confirmButton,
            (popups[1] as? TTFlashWarningAlertViewController)?.confirmButton,
            (popups[2] as? TTPopupTimeoverViewController)?.confirmButton,
            (popups[3] as? TTPopupSelectedSkinViewController)?.startButton,
        ].compactMap({ $0 })
        for button in primaryButtons {
            XCTAssertEqual(
                button.backgroundColor?.resolvedColor(with: darkTraits),
                expectedPrimaryAction
            )
        }

        let retake = TTPopupCheckedResultViewController.instantiate(
            item: AIScanRetakeGuideItem(
                title: "Hold still",
                wrongTitle: "Wrong",
                rightTitle: "Right",
                wrongImage: UIImage(),
                rightImage: UIImage()
            ),
            onRetake: {}
        )
        retake.overrideUserInterfaceStyle = .dark
        retake.loadViewIfNeeded()
        retake.collectionView.layoutIfNeeded()
        let cell = try XCTUnwrap(
            retake.collectionView.dataSource?.collectionView(
                retake.collectionView,
                cellForItemAt: IndexPath(item: 0, section: 0)
            ) as? TTPopupCheckedResultCell
        )
        let expectedShadow = try XCTUnwrap(
            UIColor(
                named: "AISDisabledSurface",
                in: AIScanCameraResourceBundle.bundle,
                compatibleWith: darkTraits
            )
        )
        XCTAssertEqual(
            cell.wellIconShadow.backgroundColor?.resolvedColor(with: darkTraits),
            expectedShadow.resolvedColor(with: darkTraits)
        )
        XCTAssertEqual(
            cell.wrongIconShadow.backgroundColor?.resolvedColor(with: darkTraits),
            expectedShadow.resolvedColor(with: darkTraits)
        )
        XCTAssertEqual(
            retake.confirmButton.backgroundColor?.resolvedColor(with: darkTraits),
            UIColor(
                red: 0x33 / 255,
                green: 0x34 / 255,
                blue: 0x44 / 255,
                alpha: 1
            )
        )
    }

    @MainActor
    func testEveryOriginalNonJointGuideLottieIsPackagedAsValidJSON() throws {
        let resourceNames = [
            "guideDogEye",
            "guideDogBody",
            "guideDogEar",
            "guideDogPaw",
            "guideDogTeeth",
            "guideCatEye",
            "guideCatTeeth",
        ]

        for resourceName in resourceNames {
            let url = try XCTUnwrap(
                AIScanCameraResourceBundle.bundle.url(
                    forResource: resourceName,
                    withExtension: "json"
                ),
                "Missing original guide Lottie: \(resourceName).json"
            )
            let data = try Data(contentsOf: url)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any]
            )
            XCTAssertNotNil(json["layers"])
            XCTAssertNotNil(json["fr"])
            XCTAssertNotNil(json["op"])
        }
    }

    @MainActor
    func testFiveSupportedProductPathsSelectTheirOriginalGuideMedia() throws {
        let cases: [(AISCPetType, AISCPartType, String?, AIScanGuideLottie)] = [
            (.dog, .eye, nil, .dogEye),
            (.dog, .teeth, nil, .dogTeeth),
            (.dog, .skin, "ear", .dogEar),
            (.dog, .skin, "belly", .dogBody),
            (.dog, .skin, "foot", .dogPaw),
            (.cat, .eye, nil, .catEye),
            (.cat, .teeth, nil, .catTeeth),
        ]

        for (pet, part, position, expected) in cases {
            let context = AISCScanContext()
            context.petType = pet
            context.partType = part
            context.analysisPosition = position

            XCTAssertEqual(AIScanGuideLottie(context: context), expected)
        }
    }

    @MainActor
    func testGuideDismissesFromOriginalLottieCompletionInsteadOfFixedDeadline() throws {
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let guide = PreviewGuideViewController.instantiate(context: context)
        var dismissCount = 0
        guide.onDismiss = { dismissCount += 1 }

        guide.loadViewIfNeeded()
        guide.beginAppearanceTransition(true, animated: false)
        guide.endAppearanceTransition()
        let player = try XCTUnwrap(
            guide.children.compactMap { $0 as? AIScanLottiePlayerController }.first,
            "The original guide Lottie player was not installed."
        )
        player.completion?()
        player.completion?()

        XCTAssertEqual(dismissCount, 1)
    }

    @MainActor
    func testDogEyeOriginalGuideActuallyPlaysThroughItsCompletionEvent() async throws {
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let guide = PreviewGuideViewController.instantiate(context: context)
        let completed = expectation(description: "original dog-eye Lottie completed")
        completed.assertForOverFulfill = true
        guide.onDismiss = { completed.fulfill() }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = guide
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await fulfillment(of: [completed], timeout: 12)
    }

    @MainActor
    func testAlertPrimaryAndSecondaryActionsUseTheContainerDismissalRoute() async {
        let primaryDismisser = MockPopupDismisser()
        var primaryCount = 0
        let primary = TTPopupAlertViewController.instantiate(
            title: "Notice",
            primaryTitle: "Settings",
            secondaryTitle: "Close",
            onPrimary: { primaryCount += 1 },
            onSecondary: nil
        )
        let primaryContainer = AIScanLegacyPopupContainer(
            content: primary,
            popupDismisser: primaryDismisser
        )
        primaryContainer.loadViewIfNeeded()
        primary.confirm(primary.confirmButton as Any)

        for _ in 0..<10 where primaryDismisser.callCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(primaryDismisser.callCount, 1)
        XCTAssertEqual(primaryCount, 1)

        let secondaryDismisser = MockPopupDismisser()
        var secondaryCount = 0
        let secondary = TTPopupAlertViewController.instantiate(
            title: "Notice",
            primaryTitle: "Retry",
            secondaryTitle: "Close",
            onPrimary: nil,
            onSecondary: { secondaryCount += 1 }
        )
        let secondaryContainer = AIScanLegacyPopupContainer(
            content: secondary,
            popupDismisser: secondaryDismisser
        )
        secondaryContainer.loadViewIfNeeded()
        secondary.cancel(secondary.cancelButton as Any)

        for _ in 0..<10 where secondaryDismisser.callCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(secondaryDismisser.callCount, 1)
        XCTAssertEqual(secondaryCount, 1)
    }

    @MainActor
    func testGuideFlashAndSkinActionsUseTheContainerDismissalRoute() async {
        let guideDismisser = MockPopupDismisser()
        var guideCount = 0
        let timeover = TTPopupTimeoverViewController.instantiate(
            onRetry: {},
            onGuide: { guideCount += 1 }
        )
        let guideContainer = AIScanLegacyPopupContainer(
            content: timeover,
            popupDismisser: guideDismisser
        )
        guideContainer.loadViewIfNeeded()
        timeover.cancel(timeover.cancelButton as Any)

        for _ in 0..<10 where guideDismisser.callCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(guideDismisser.callCount, 1)
        XCTAssertEqual(guideCount, 1)

        let flashDismisser = MockPopupDismisser()
        var selectedFlash: Bool?
        let flash = TTFlashWarningAlertViewController.instantiate(
            showsSkinGuidance: true,
            startsWithFlash: false,
            onStart: { selectedFlash = $0 }
        )
        let flashContainer = AIScanLegacyPopupContainer(
            content: flash,
            popupDismisser: flashDismisser
        )
        flashContainer.loadViewIfNeeded()
        flash.didTapFlashButton(flash.flashButton as Any)
        flash.confirm(flash.confirmButton as Any)

        for _ in 0..<10 where flashDismisser.callCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(flashDismisser.callCount, 1)
        XCTAssertEqual(selectedFlash, true)

        let skinDismisser = MockPopupDismisser()
        var selectedPosition: String?
        let skin = TTPopupSelectedSkinViewController.instantiate(
            onStart: { position, _ in selectedPosition = position },
            onClose: {}
        )
        let skinContainer = AIScanLegacyPopupContainer(
            content: skin,
            popupDismisser: skinDismisser
        )
        skinContainer.loadViewIfNeeded()
        skin.earAction(skin.earContainer as Any)
        skin.start(skin.startButton as Any)

        for _ in 0..<10 where skinDismisser.callCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(skinDismisser.callCount, 1)
        XCTAssertEqual(selectedPosition, "ear")
    }

    @MainActor
    func testSkinSelectionCommitsBeforePopupDismissalCompletion() async {
        let dismisser = DeferredPopupDismisser()
        var selectedPosition: String?
        let skin = TTPopupSelectedSkinViewController.instantiate(
            onStart: { position, _ in selectedPosition = position },
            onClose: {}
        )
        let container = AIScanLegacyPopupContainer(
            content: skin,
            popupDismisser: dismisser
        )
        container.loadViewIfNeeded()

        skin.footAction(skin.footContainer as Any)
        skin.start(skin.startButton as Any)

        XCTAssertEqual(selectedPosition, "foot")
        for _ in 0..<10 where dismisser.callCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(dismisser.callCount, 1)
    }

    @MainActor
    func testRequiredSkinSelectionAppearsAfterCameraPresentationBeforeCorePreparation() async throws {
        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .skin
        let camera = AIScanCameraViewController(
            cameraController: AIScanCameraController(cameraEngine: engine),
            context: context
        )

        camera.loadViewIfNeeded()
        XCTAssertNil(camera.presentedViewController)
        XCTAssertTrue(engine.preparedContexts.isEmpty)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.beginAppearanceTransition(true, animated: false)
        camera.endAppearanceTransition()

        for _ in 0..<20 where camera.presentedViewController == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let popup = try XCTUnwrap(
            camera.presentedViewController?.children
                .compactMap { $0 as? TTPopupSelectedSkinViewController }
                .first
        )
        XCTAssertTrue(engine.preparedContexts.isEmpty)

        popup.bodyAction(popup.bodyContainer as Any)
        popup.start(popup.startButton as Any)

        for _ in 0..<40 where engine.preparedContexts.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(context.analysisPosition, "belly")
        XCTAssertEqual(engine.preparedContexts.last?.analysisPosition, "belly")
        XCTAssertEqual(engine.startRunningCount, 1)
    }

    @MainActor
    func testRetakePopupRestoresTheOriginalMultiReasonPageIndicator() throws {
        let popup = TTPopupCheckedResultViewController.instantiate(
            items: [
                AIScanRetakeGuideItem(
                    title: "사진을 다시 확인해 주세요",
                    wrongTitle: "흐린 사진",
                    rightTitle: "선명한 사진",
                    wrongImage: nil,
                    rightImage: nil
                ),
                AIScanRetakeGuideItem(
                    title: "눈 전체가 보이게 촬영해 주세요",
                    wrongTitle: "잘린 사진",
                    rightTitle: "올바른 사진",
                    wrongImage: nil,
                    rightImage: nil
                ),
            ],
            onRetake: {}
        )
        popup.loadViewIfNeeded()
        popup.view.frame = CGRect(x: 0, y: 0, width: 378, height: 413)
        popup.view.layoutIfNeeded()

        XCTAssertFalse(popup.indicatorContainer.isHidden)
        let indicator = try XCTUnwrap(
            popup.indicatorContainer.subviews.first {
                $0.accessibilityIdentifier == "aiscan.camera.retake.page-indicator"
            }
        )
        XCTAssertEqual(indicator.subviews.count, 2)
        XCTAssertEqual(indicator.subviews[0].bounds.width, 23, accuracy: 0.5)
        XCTAssertEqual(indicator.subviews[1].bounds.width, 8, accuracy: 0.5)

        popup.collectionView.contentOffset.x = popup.collectionView.bounds.width
        popup.collectionView.delegate?.scrollViewDidScroll?(popup.collectionView)
        indicator.layoutIfNeeded()

        XCTAssertEqual(indicator.subviews[0].bounds.width, 8, accuracy: 0.5)
        XCTAssertEqual(indicator.subviews[1].bounds.width, 23, accuracy: 0.5)
    }

    @MainActor
    func testOriginalSkinSelectionCopyAndControlStatesAreRestored() {
        let popup = TTPopupSelectedSkinViewController.instantiate(
            onStart: { _, _ in },
            onClose: {}
        )
        popup.loadViewIfNeeded()

        XCTAssertEqual(popup.titleLabel.text, AIScanCameraStrings.localizedMessageKey("popup.skin.title"))
        XCTAssertEqual(popup.earSubtitleLabel.text, AIScanCameraStrings.localizedMessageKey("popup.skin.ear_detail"))
        XCTAssertEqual(popup.bodySubtitleLabel.text, AIScanCameraStrings.localizedMessageKey("popup.skin.body_detail"))
        XCTAssertEqual(popup.footSubtitleLabel.text, AIScanCameraStrings.localizedMessageKey("popup.skin.foot_detail"))
        XCTAssertTrue(
            popup.descriptionLabel.text == AIScanCameraStrings.localized(.flashSubtitle)
        )
        XCTAssertTrue(
            popup.warningLabel.text == AIScanCameraStrings.localizedMessageKey("popup.skin.warning")
        )
        XCTAssertFalse(popup.startButton.isEnabled)
        XCTAssertEqual(popup.view.accessibilityIdentifier, "aiscan.camera.skin-selection")
        XCTAssertEqual(
            popup.bodyContainer.accessibilityIdentifier,
            "aiscan.camera.skin-selection.belly"
        )
        XCTAssertEqual(
            popup.startButton.accessibilityIdentifier,
            "aiscan.camera.skin-selection.start"
        )
        XCTAssertEqual(
            popup.flashButton.accessibilityIdentifier,
            "aiscan.camera.skin-selection.flash"
        )
    }

    @MainActor
    func testLegacyPopupsKeepOriginalHelveticaNeueTypography() throws {
        let alert = TTPopupAlertViewController.instantiate(
            title: "Title",
            subtitle: "Subtitle",
            primaryTitle: "OK",
            secondaryTitle: "Cancel",
            onPrimary: nil,
            onSecondary: nil
        )
        alert.loadViewIfNeeded()

        let flash = TTFlashWarningAlertViewController.instantiate(
            showsSkinGuidance: true,
            startsWithFlash: false,
            onStart: { _ in }
        )
        flash.loadViewIfNeeded()

        let timeover = TTPopupTimeoverViewController.instantiate(
            onRetry: {},
            onGuide: {}
        )
        timeover.loadViewIfNeeded()

        let skin = TTPopupSelectedSkinViewController.instantiate(
            onStart: { _, _ in },
            onClose: {}
        )
        skin.loadViewIfNeeded()

        XCTAssertEqual(try fontName(in: alert.titleLabel), "HelveticaNeue-Bold")
        XCTAssertEqual(try fontName(in: alert.subtitleLabel), "HelveticaNeue")
        XCTAssertEqual(try fontName(in: flash.titleLabel), "HelveticaNeue-Bold")
        XCTAssertEqual(try fontName(in: flash.subtitleLabel), "HelveticaNeue")
        XCTAssertEqual(try fontName(in: timeover.titleLabel), "HelveticaNeue-Bold")
        XCTAssertEqual(try fontName(in: timeover.subtitleLabel), "HelveticaNeue")
        XCTAssertEqual(try fontName(in: skin.flashDescriptionLabel), "HelveticaNeue")
        XCTAssertEqual(try fontName(in: skin.descriptionLabel), "HelveticaNeue")
        XCTAssertEqual(try fontName(in: skin.warningLabel), "HelveticaNeue-Bold")
    }

    @MainActor
    func testPopupGuidanceTextKeepsTheOriginalTypographyAndKoreanWrapping() throws {
        let flash = TTFlashWarningAlertViewController.instantiate(
            showsSkinGuidance: true,
            startsWithFlash: false,
            onStart: { _ in }
        )
        flash.loadViewIfNeeded()

        let skin = TTPopupSelectedSkinViewController.instantiate(
            onStart: { _, _ in },
            onClose: {}
        )
        skin.loadViewIfNeeded()

        XCTAssertEqual(
            flash.skinWarningLabel.text,
            AIScanCameraStrings.localizedMessageKey("popup.skin.warning")
        )
        try assertOriginalPopupTypography(flash.flashWarningLabel, pointSize: 13)
        try assertOriginalPopupTypography(skin.flashDescriptionLabel, pointSize: 13)
        try assertOriginalPopupTypography(flash.skinWarningLabel, pointSize: 12)
        try assertOriginalPopupTypography(skin.warningLabel, pointSize: 12)

        if #available(iOS 14.0, *) {
            for optionalLabel in [flash.subtitleLabel, skin.descriptionLabel] {
                let label = try XCTUnwrap(optionalLabel)
                let attributed = try XCTUnwrap(label.attributedText)
                let paragraph = try XCTUnwrap(
                    attributed.attribute(
                        NSAttributedString.Key.paragraphStyle,
                        at: 0,
                        effectiveRange: nil
                    )
                        as? NSParagraphStyle
                )
                XCTAssertTrue(
                    paragraph.lineBreakStrategy.contains(
                        NSParagraphStyle.LineBreakStrategy.hangulWordPriority
                    )
                )
            }
        }
    }

    @MainActor
    func testSkinSelectionPopupRestoresCurrentPartAndFlashState() {
        let popup = TTPopupSelectedSkinViewController.instantiate(
            initialPosition: "foot",
            startsWithFlash: true,
            onStart: { _, _ in },
            onClose: {}
        )
        popup.loadViewIfNeeded()

        XCTAssertTrue(popup.startButton.isEnabled)
        XCTAssertTrue(popup.flashButton.isSelected)
        XCTAssertEqual(popup.footContainer.layer.borderWidth, 1)
        XCTAssertEqual(popup.earContainer.layer.borderWidth, 0)
        XCTAssertEqual(popup.bodyContainer.layer.borderWidth, 0)
    }

    @MainActor
    func testPresetSkinPartHidesSelectorWhileGenericSkinKeepsIt() throws {
        let presetContext = AISCScanContext()
        presetContext.petType = .dog
        presetContext.partType = .skin
        presetContext.analysisPosition = "ear"
        let presetCamera = AIScanCameraViewController(
            cameraController: AIScanCameraController(cameraEngine: MockCameraEngine()),
            context: presetContext
        )
        presetCamera.beginsScanningAutomatically = false
        presetCamera.loadViewIfNeeded()
        let presetSelector = try XCTUnwrap(
            presetCamera.view.descendant(accessibilityIdentifier: "aiscan.camera.skin-part")
        )

        let genericContext = AISCScanContext()
        genericContext.petType = .dog
        genericContext.partType = .skin
        let genericCamera = AIScanCameraViewController(
            cameraController: AIScanCameraController(cameraEngine: MockCameraEngine()),
            context: genericContext
        )
        genericCamera.beginsScanningAutomatically = false
        genericCamera.loadViewIfNeeded()
        let genericSelector = try XCTUnwrap(
            genericCamera.view.descendant(accessibilityIdentifier: "aiscan.camera.skin-part")
        )

        XCTAssertTrue(presetSelector.isHidden)
        XCTAssertFalse(genericSelector.isHidden)
    }

    @MainActor
    func testSkinPartChangeRepreparesAndReconfiguresCoreWithNewPosition() async {
        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .skin
        context.analysisPosition = "ear"
        let camera = AIScanCameraViewController(
            cameraController: AIScanCameraController(cameraEngine: engine),
            context: context
        )
        camera.beginsScanningAutomatically = false
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        context.analysisPosition = "foot"
        context.displaySubpart = "FOOT"
        camera.reprepareCurrentSession()
        for _ in 0..<20 where engine.startRunningCount == 0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(engine.resetCount, 1)
        XCTAssertEqual(engine.preparedContexts.count, 1)
        XCTAssertEqual(engine.preparedContexts.last?.analysisPosition, "foot")
        XCTAssertEqual(engine.configuredPositions, [.back])
        XCTAssertEqual(engine.startRunningCount, 1)
    }

    @MainActor
    func testSkinAreaSelectionPreparesCoreWithProviderPositionForEveryChoice() async throws {
        for position in ["ear", "belly", "foot"] {
            let engine = MockCameraEngine()
            engine.emitsPreparationProgress = false
            let context = AISCScanContext()
            context.petType = .dog
            context.partType = .skin
            let camera = AIScanCameraViewController(
                cameraController: AIScanCameraController(cameraEngine: engine),
                context: context
            )
            camera.beginsScanningAutomatically = false

            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = camera
            window.makeKeyAndVisible()
            camera.loadViewIfNeeded()
            camera.beginAppearanceTransition(true, animated: false)
            camera.endAppearanceTransition()
            camera.showSkinPositionSelection()

            let popup = try XCTUnwrap(
                camera.presentedViewController?.children
                    .compactMap { $0 as? TTPopupSelectedSkinViewController }
                    .first,
                "The skin selector did not present for \(position)."
            )
            try await Task.sleep(nanoseconds: 500_000_000)
            switch position {
            case "ear":
                popup.earAction(popup.earContainer as Any)
            case "foot":
                popup.footAction(popup.footContainer as Any)
            default:
                popup.bodyAction(popup.bodyContainer as Any)
            }
            popup.start(popup.startButton as Any)

            for _ in 0..<30 where engine.preparedContexts.isEmpty {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            XCTAssertEqual(context.analysisPosition, position)
            XCTAssertEqual(context.analysisSubpart, nil)
            XCTAssertEqual(context.displaySubpart, position.uppercased())
            XCTAssertEqual(
                engine.preparedContexts.last?.analysisPosition,
                position,
                "The \(position) choice did not reach the private Core preparation context."
            )
            window.isHidden = true
        }
    }

    @MainActor
    func testOriginalCameraCaptureAndGuideSurfaceStatesAreRestored() {
        let camera = CameraViewController.instantiate(partType: .skin)
        camera.loadViewIfNeeded()
        camera.configureControls(showsPartSelector: true, showsGuide: true, showsAlbum: true)
        let idleImage = camera.captureButton.image(for: .normal)

        camera.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        camera.view.layoutIfNeeded()
        let albumButton = camera.view.descendant(
            accessibilityIdentifier: "aiscan.camera.album"
        ) as? UIButton
        XCTAssertNotNil(albumButton)
        XCTAssertFalse(albumButton?.isHidden ?? true)
        XCTAssertEqual(albumButton?.bounds.size, CGSize(width: 44, height: 44))
        let captureCenter = camera.captureButtonContainer.superview?.convert(
            camera.captureButtonContainer.center,
            to: camera.view
        )
        XCTAssertEqual(albumButton?.center.y ?? 0, captureCenter?.y ?? 0, accuracy: 0.5)

        camera.setCaptureAttempt(active: true, progress: 0.5)
        XCTAssertTrue(camera.closeButton.isHidden)
        XCTAssertTrue(camera.flashButton.isHidden)
        XCTAssertTrue(camera.guideButton.isHidden)
        XCTAssertTrue(camera.partSelectedContainer?.isHidden == true)
        XCTAssertTrue(albumButton?.isHidden == true)
        XCTAssertNotEqual(camera.captureButton.image(for: .normal)?.pngData(), idleImage?.pngData())

        camera.setCaptureAttempt(active: false)
        XCTAssertFalse(camera.closeButton.isHidden)
        XCTAssertFalse(camera.flashButton.isHidden)
        XCTAssertFalse(camera.guideButton.isHidden)
        XCTAssertFalse(camera.partSelectedContainer?.isHidden ?? true)
        XCTAssertFalse(albumButton?.isHidden ?? true)
        XCTAssertEqual(camera.captureButton.image(for: .normal)?.pngData(), idleImage?.pngData())
    }

    @MainActor
    func testOriginalCameraChromeColorsAndCornerRadiiAreRestored() throws {
        let camera = CameraViewController.instantiate(partType: .skin)
        camera.loadViewIfNeeded()

        let activityIndicator = try XCTUnwrap(camera.optionActivityIndicator)
        XCTAssertEqual(
            activityIndicator.color,
            UIColor(
                red: 247 / 255,
                green: 111 / 255,
                blue: 79 / 255,
                alpha: 1
            )
        )

        let pauseIcons = try XCTUnwrap(camera.pauseIcons)
        XCTAssertFalse(pauseIcons.isEmpty)
        pauseIcons.forEach {
            XCTAssertEqual($0.layer.cornerRadius, 1.5, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testAlbumSelectionRestoresOriginalLayoutAndSkinAreas() throws {
        let album = AIScanAlbumSelectionViewController(
            allowsPositionSelection: true,
            initialPosition: "belly"
        )
        album.loadViewIfNeeded()
        album.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        album.view.layoutIfNeeded()

        let card = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.photo-card"
        ))
        let close = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.close"
        ) as? UIButton)
        let select = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.select-photo"
        ) as? UIButton)
        let selectLabel = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.select-photo.label"
        ) as? UILabel)
        let preview = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.preview"
        ) as? UIImageView)
        let analyze = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.analyze"
        ) as? UIButton)
        let analyzeLabel = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.analyze.label"
        ) as? UILabel)
        let ear = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.area.ear"
        ) as? UIButton)

        XCTAssertEqual(card.bounds.height, 380, accuracy: 0.5)
        XCTAssertEqual(card.layer.cornerRadius, 12)
        let photoBorder = try XCTUnwrap(card.layer.sublayers?.first {
            $0.name == "aiscan.album.photo-border"
        } as? CAShapeLayer)
        let selectBorder = try XCTUnwrap(select.layer.sublayers?.first {
            $0.name == "aiscan.album.select-photo-border"
        } as? CAShapeLayer)
        XCTAssertEqual(photoBorder.lineWidth, 1)
        XCTAssertEqual(photoBorder.path?.boundingBox, card.bounds)
        XCTAssertEqual(selectBorder.lineDashPattern, [4])
        XCTAssertEqual(selectBorder.lineDashPhase, 7)
        XCTAssertEqual(
            selectBorder.path?.boundingBox,
            select.bounds.insetBy(dx: 0.5, dy: 0.5)
        )
        XCTAssertEqual(close.bounds, CGRect(x: 0, y: 0, width: 60, height: 48))
        XCTAssertEqual(close.frame.midX, album.view.bounds.maxX - 30, accuracy: 0.5)
        let earFrame = ear.convert(ear.bounds, to: album.view)
        let selectFrame = select.convert(select.bounds, to: album.view)
        let analyzeFrame = analyze.convert(analyze.bounds, to: album.view)
        XCTAssertEqual(earFrame.minY, close.frame.maxY + 16, accuracy: 0.5)
        XCTAssertEqual(selectFrame.minY, earFrame.maxY + 19, accuracy: 0.5)
        XCTAssertEqual(analyzeFrame.maxY, album.view.bounds.maxY - 20, accuracy: 0.5)
        XCTAssertEqual(preview.contentMode, .scaleAspectFill)
        XCTAssertTrue(preview.clipsToBounds)
        XCTAssertFalse(analyze.isEnabled)
        XCTAssertEqual(
            selectLabel.textColor.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(red: 0x99 / 255, green: 0x99 / 255, blue: 0x99 / 255, alpha: 1)
        )
        XCTAssertEqual(selectLabel.font.pointSize, 16)
        XCTAssertEqual(analyzeLabel.font.pointSize, 17)
        XCTAssertEqual(
            UIColor(cgColor: try XCTUnwrap(photoBorder.strokeColor)),
            UIColor(red: 0xEB / 255, green: 0xED / 255, blue: 0xF0 / 255, alpha: 1)
        )
        let emptyLabel = try XCTUnwrap(album.view.allLabels.first {
            $0.text == AIScanCameraStrings.localizedMessageKey("album.empty")
        })
        XCTAssertEqual(
            emptyLabel.textColor.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(red: 0x99 / 255, green: 0x99 / 255, blue: 0x99 / 255, alpha: 1)
        )
        XCTAssertEqual(
            analyzeLabel.text,
            AIScanCameraStrings.localizedMessageKey("album.analyze")
        )
        XCTAssertEqual(
            AIScanCameraStrings.localizedMessageKey("album.analyze", languageCode: "ko"),
            "AI 분석하기"
        )
        XCTAssertEqual(
            AIScanCameraStrings.localizedMessageKey("album.analyze", languageCode: "en"),
            "AI Analysis"
        )
        XCTAssertEqual(
            AIScanCameraStrings.localizedMessageKey("album.analyze", languageCode: "ja"),
            "AI分析"
        )
        for position in ["ear", "belly", "foot"] {
            XCTAssertNotNil(album.view.descendant(
                accessibilityIdentifier: "aiscan.album.area.\(position)"
            ))
        }

        album.setValidationMessage("validation")
        let validation = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.validation"
        ))
        XCTAssertFalse(validation.isHidden)
        let validationLabel = try XCTUnwrap(validation.allLabels.first)
        let paragraph = try XCTUnwrap(
            validationLabel.attributedText?.attribute(
                .paragraphStyle,
                at: 0,
                effectiveRange: nil
            ) as? NSParagraphStyle
        )
        XCTAssertEqual(validationLabel.font.pointSize, 17)
        XCTAssertEqual(paragraph.lineSpacing, 4)
        XCTAssertEqual(
            validationLabel.textColor.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor.red
        )

        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        XCTAssertEqual(
            ear.titleColor(for: .normal)?.resolvedColor(with: darkTraits),
            AIScanReferenceTheme.brandPrimary.resolvedColor(with: darkTraits)
        )
    }

    @MainActor
    func testAlbumValidationKeepsTheSelectedActionAppearanceWhileWorkRuns() async throws {
        let album = AIScanAlbumSelectionViewController(
            allowsPositionSelection: false,
            initialPosition: nil
        )
        album.loadViewIfNeeded()
        let analyze = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.analyze"
        ) as? UIButton)
        let analyzeLabel = try XCTUnwrap(album.view.descendant(
            accessibilityIdentifier: "aiscan.album.analyze.label"
        ) as? UILabel)
        let picker = UIImagePickerController()

        album.imagePickerController(
            picker,
            didFinishPickingMediaWithInfo: [.originalImage: UIImage()]
        )
        for _ in 0..<20 where !analyze.isEnabled {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(analyze.isEnabled)
        let selectedBackground = try XCTUnwrap(analyze.layer.sublayers?.first {
            $0.name == "aiscan.album.analyze-background"
        } as? CAShapeLayer).fillColor

        album.setAnalyzing(true)

        XCTAssertFalse(analyze.isEnabled)
        XCTAssertEqual(
            analyzeLabel.text,
            AIScanCameraStrings.localizedMessageKey("album.analyze")
        )
        let runningBackground = try XCTUnwrap(analyze.layer.sublayers?.first {
            $0.name == "aiscan.album.analyze-background"
        } as? CAShapeLayer).fillColor
        XCTAssertEqual(runningBackground, selectedBackground)

        album.setAnalyzing(false)
        XCTAssertTrue(analyze.isEnabled)
    }

    @MainActor
    func testAlbumRetryAfterAcceptedPreviewReturnsToInlineMessageInsteadOfCameraPopup() async throws {
        let guideKey = "com.aiforpet.didShowPreviewGuide.dog.belly"
        let previousGuideValue = UserDefaults.standard.object(forKey: guideKey)
        UserDefaults.standard.set(true, forKey: guideKey)
        defer {
            if let previousGuideValue {
                UserDefaults.standard.set(previousGuideValue, forKey: guideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: guideKey)
            }
        }

        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .skin
        context.analysisPosition = "belly"
        context.displayMetadata = ["show_flash_warning": "false"]
        let camera = AIScanCameraViewController(cameraController: controller, context: context)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()
        camera.beginAppearanceTransition(true, animated: false)
        camera.endAppearanceTransition()

        for _ in 0..<30 where engine.configuredPositions.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(engine.preparedContexts.count, 1)
        XCTAssertEqual(engine.configuredPositions, [.back])
        XCTAssertGreaterThan(engine.startRunningCount, 0)
        let albumButton = try XCTUnwrap(camera.view.descendant(
            accessibilityIdentifier: "aiscan.camera.album"
        ) as? UIButton)
        XCTAssertTrue(albumButton.isEnabled)
        camera.showAlbumSelection()

        var album = camera.presentedViewController as? AIScanAlbumSelectionViewController
        for _ in 0..<30 where album == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
            album = camera.presentedViewController as? AIScanAlbumSelectionViewController
        }
        let resolvedAlbum = try XCTUnwrap(
            album,
            "Album did not present. presented=\(String(describing: camera.presentedViewController)) "
                + "buttonHidden=\(albumButton.isHidden) autoCapture=\(engine.automaticallyCapturesReadyFrames)"
        )
        let picker = UIImagePickerController()
        let selectedImage = UIGraphicsImageRenderer(
            size: CGSize(width: 160, height: 160)
        ).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
        }
        resolvedAlbum.imagePickerController(
            picker,
            didFinishPickingMediaWithInfo: [.originalImage: selectedImage]
        )
        for _ in 0..<30 where resolvedAlbum.view.descendant(
            accessibilityIdentifier: "aiscan.album.preview"
        )?.isHidden != false {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        resolvedAlbum.setAnalyzing(true)
        resolvedAlbum.onAnalyze?(selectedImage, "belly")
        for _ in 0..<20 where engine.diagnosedPhotoImages.isEmpty {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(
            engine.diagnosedPhotoImages.count,
            1,
            "The album analysis callback did not reach Core."
        )

        camera.aiscanCameraController(controller, didCapturePreview: UIImage())
        for _ in 0..<30 where camera.presentedViewController === resolvedAlbum {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        camera.aiscanCameraController(
            controller,
            didFail: NSError(
                domain: AISCErrorDomain,
                code: AISCErrorCode.frameRejected.rawValue,
                userInfo: [
                    AISCRetryableKey: true,
                    AISCDisplayReasonKey: "몸통을 더 가까이 촬영해 주세요.",
                ]
            )
        )

        for _ in 0..<30 where camera.presentedViewController !== resolvedAlbum {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(
            camera.presentedViewController === resolvedAlbum,
            "The accepted album photo did not return to the same selection surface after retry."
        )
        let validation = try XCTUnwrap(resolvedAlbum.view.descendant(
            accessibilityIdentifier: "aiscan.album.validation"
        ))
        XCTAssertFalse(validation.isHidden, "The restored album did not expose inline guidance.")
        XCTAssertTrue(
            validation.allLabels.contains { !($0.text?.isEmpty ?? true) },
            "The restored album inline guidance was empty."
        )
        XCTAssertNil(resolvedAlbum.view.descendant(
            accessibilityIdentifier: "aiscan.camera.retry"
        ))
    }

    @MainActor
    func testRetainedAlbumControllerDoesNotBlockQuestionnaireAfterTransition() async throws {
        let guideKey = "com.aiforpet.didShowPreviewGuide.dog.belly"
        let previousGuideValue = UserDefaults.standard.object(forKey: guideKey)
        UserDefaults.standard.set(true, forKey: guideKey)
        defer {
            if let previousGuideValue {
                UserDefaults.standard.set(previousGuideValue, forKey: guideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: guideKey)
            }
        }

        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .skin
        context.analysisPosition = "belly"
        context.questionnaireEnabled = true
        context.displayMetadata = ["show_flash_warning": "false"]
        let surfaceCoordinator = MockTransientSurfaceCoordinator()
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: MockCameraStackDismisser(),
            transientSurfaceCoordinator: surfaceCoordinator
        )

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()
        camera.beginAppearanceTransition(true, animated: false)
        camera.endAppearanceTransition()

        for _ in 0..<30 where engine.configuredPositions.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        camera.showAlbumSelection()
        var album = camera.presentedViewController as? AIScanAlbumSelectionViewController
        for _ in 0..<30 where album == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
            album = camera.presentedViewController as? AIScanAlbumSelectionViewController
        }
        let resolvedAlbum = try XCTUnwrap(album)
        let selectedImage = UIGraphicsImageRenderer(
            size: CGSize(width: 160, height: 160)
        ).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
        }
        resolvedAlbum.setAnalyzing(true)
        resolvedAlbum.onAnalyze?(selectedImage, "belly")
        XCTAssertEqual(engine.diagnosedPhotoImages.count, 1)

        camera.aiscanCameraController(controller, didCapturePreview: selectedImage)
        XCTAssertEqual(surfaceCoordinator.dismissPresentedSurfaceCount, 1)
        let requestedQuestionnaire = AISCQuestionnaire(prompts: [
            AISCQuestionnairePrompt(identifier: "q1", text: "피부를 자주 긁나요?"),
        ])
        XCTAssertTrue(camera.scanContext.questionnaireEnabled)
        XCTAssertEqual(requestedQuestionnaire.prompts.count, 1)
        camera.aiscanCameraController(controller, didRequest: requestedQuestionnaire)

        let questionnaireValue = Mirror(reflecting: camera).children.first {
            $0.label == "questionnaireController"
        }?.value
        let questionnaireController = questionnaireValue.flatMap {
            Mirror(reflecting: $0).children.first?.value as? UIViewController
        }
        XCTAssertEqual(
            questionnaireController?.view.accessibilityIdentifier,
            "aiscan.questionnaire",
            "A retained album controller is retry state, not a visible surface."
        )
    }

    @MainActor
    func testCaptureAttemptRestoresOriginalFanProgressGeometry() throws {
        let camera = CameraViewController.instantiate(partType: .eye)
        camera.loadViewIfNeeded()
        camera.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        camera.view.setNeedsLayout()
        camera.view.layoutIfNeeded()

        XCTAssertTrue(camera.captureButton.layer.masksToBounds)
        XCTAssertEqual(
            camera.captureButton.layer.cornerRadius,
            camera.captureButton.bounds.width / 2,
            accuracy: 0.000_001
        )

        camera.setCaptureAttempt(active: true, progress: 0.25)

        let fan = try XCTUnwrap(
            camera.view.descendant(
                accessibilityIdentifier: "aiscan.camera.capture.fan-progress"
            ) as? TTFanProgressView
        )
        XCTAssertFalse(fan.isHidden)
        XCTAssertEqual(fan.progress, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(fan.renderedStrokeEnd, 0.75, accuracy: 0.000_001)
        XCTAssertEqual(fan.frame, camera.captureButtonContainer.bounds)

        camera.setCaptureAttempt(active: false)
        XCTAssertTrue(fan.isHidden)
        XCTAssertEqual(fan.progress, 0, accuracy: 0.000_001)
    }

    @MainActor
    func testActiveCaptureArtworkIsCircularInsteadOfSquareCropped() throws {
        let camera = CameraViewController.instantiate(partType: .eye)
        camera.loadViewIfNeeded()
        camera.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        camera.view.layoutIfNeeded()

        camera.setCaptureAttempt(active: true)

        let image = try XCTUnwrap(camera.captureButton.image(for: .normal))
        XCTAssertEqual(
            image.size,
            camera.captureButton.bounds.size,
            "The active gradient must fill the original 80pt shutter so the fan leaves a 4pt ring."
        )
        let cgImage = try XCTUnwrap(image.cgImage)
        let data = try XCTUnwrap(cgImage.dataProvider?.data)
        let bytes = CFDataGetBytePtr(data)
        let alphaInfo = cgImage.alphaInfo
        XCTAssertTrue(
            alphaInfo == .premultipliedLast || alphaInfo == .premultipliedFirst
                || alphaInfo == .last || alphaInfo == .first,
            "Active capture art must carry its own alpha mask."
        )

        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        let cornerOffset = 0
        let centerOffset = (cgImage.height / 2) * cgImage.bytesPerRow
            + (cgImage.width / 2) * bytesPerPixel
        let alphaIndex = alphaInfo == .premultipliedFirst || alphaInfo == .first ? 0 : 3
        XCTAssertEqual(bytes?[cornerOffset + alphaIndex], 0)
        XCTAssertGreaterThan(bytes?[centerOffset + alphaIndex] ?? 0, 0)
    }

    @MainActor
    func testCaptureAttemptRestoresOriginalSoundAndHapticSequence() async throws {
        let camera = CameraViewController.instantiate(partType: .eye)
        camera.loadViewIfNeeded()
        var sounds: [UInt32] = []
        var impacts: [UIImpactFeedbackGenerator.FeedbackStyle] = []
        var notifications: [UINotificationFeedbackGenerator.FeedbackType] = []
        camera.playSystemSound = { sounds.append($0) }
        camera.generateImpactFeedback = { impacts.append($0) }
        camera.generateNotificationFeedback = { notifications.append($0) }

        camera.setCaptureAttempt(active: true, progress: 0)
        camera.setCaptureAttempt(active: true, progress: 0.5)
        camera.setCaptureAttempt(active: false)
        camera.flashCapture()
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(sounds, [1117, 1118])
        XCTAssertEqual(impacts, [.heavy, .heavy])
        XCTAssertEqual(notifications, [.success])
    }

    @MainActor
    func testCaptureDebounceCannotReenableTheButtonWhileCameraIsPreparing() async throws {
        let camera = CameraViewController.instantiate(partType: .eye)
        camera.loadViewIfNeeded()
        camera.setPreparing(false)

        camera.capture(camera.captureButton as Any)
        camera.setPreparing(true)
        try await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertFalse(camera.captureButton.isEnabled)
        XCTAssertTrue(camera.optionActivityIndicator?.isAnimating == true)
    }

    @MainActor
    func testTorchUnavailableDisablesFlashWithoutPresentingFailure() throws {
        let engine = MockCameraEngine()
        engine.torchError = NSError(
            domain: AISCErrorDomain,
            code: 102,
            userInfo: [AISCDisplayReasonKey: "torch_unavailable"]
        )
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let camera = AIScanCameraViewController(cameraController: controller, context: context)
        camera.beginsScanningAutomatically = false
        var failureCount = 0
        camera.onFailure = { _ in failureCount += 1 }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()
        let surface = try XCTUnwrap(
            camera.children.compactMap { $0 as? CameraViewController }.first
        )
        surface.setPreparing(false)

        surface.didTapFlashButton(surface.flashButton)

        XCTAssertFalse(surface.flashButton.isEnabled)
        XCTAssertFalse(surface.flashButton.isSelected)
        XCTAssertNil(camera.presentedViewController)
        XCTAssertEqual(failureCount, 0)
    }

    @MainActor
    func testCameraEmbeddedControllersUseTheCameraSurfaceAsTheirParent() throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let camera = AIScanCameraViewController(cameraController: controller, context: context)
        camera.beginsScanningAutomatically = false
        camera.loadViewIfNeeded()

        let cameraSurface = try XCTUnwrap(
            camera.children.compactMap { $0 as? CameraViewController }.first
        )
        let overlay = try XCTUnwrap(
            cameraSurface.children.compactMap { $0 as? TTOverlayViewController }.first
        )

        XCTAssertIdentical(overlay.parent, cameraSurface)
        XCTAssertTrue(overlay.view.isDescendant(of: cameraSurface.view))
    }

    @MainActor
    func testCameraOverlayRestoresOriginalOpenAndCloseVisualStates() throws {
        let overlay = TTOverlayViewController.instantiate(partType: .eye)
        overlay.loadViewIfNeeded()

        XCTAssertEqual(overlay.view.backgroundColor, .black)

        overlay.setCameraActive(true, animated: false)
        XCTAssertEqual(overlay.view.backgroundColor, .clear)

        overlay.setCameraActive(false, animated: false)
        XCTAssertEqual(overlay.view.backgroundColor, .black)
    }

    @MainActor
    func testCameraOverlayOnlyShowsOriginalGuidanceMessages() throws {
        let overlay = TTOverlayViewController.instantiate(partType: .eye)
        overlay.loadViewIfNeeded()
        let focusAlpha = overlay.focusImageView?.alpha

        XCTAssertFalse(overlay.messageContainer.isHidden)
        XCTAssertEqual(overlay.messageLabel.alpha, 0, accuracy: 0.000_001)

        overlay.setMessage(AIScanCameraStrings.localized(.startPrompt))
        XCTAssertFalse(overlay.messageContainer.isHidden)
        XCTAssertEqual(overlay.messageLabel.alpha, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            overlay.messageLabel.text,
            AIScanCameraStrings.localized(.startPrompt)
        )

        overlay.apply(evaluation: AISCFrameEvaluation(
            scanState: .tracking,
            captureDecision: .continue,
            guidanceCode: .moveCloser,
            captureAllowed: false,
            normalizedProgress: 0.5,
            displayMessageKey: "move_closer",
            overlayHints: nil
        ))
        XCTAssertFalse(overlay.messageContainer.isHidden)
        XCTAssertEqual(
            overlay.messageLabel.text,
            AIScanCameraStrings.localizedMessageKey("move_closer")
        )

        overlay.apply(evaluation: AISCFrameEvaluation(
            scanState: .captureReady,
            captureDecision: .ready,
            guidanceCode: .none,
            captureAllowed: true,
            normalizedProgress: 1,
            displayMessageKey: "ready",
            overlayHints: nil
        ))
        XCTAssertFalse(overlay.messageContainer.isHidden)
        XCTAssertEqual(overlay.messageLabel.alpha, 0, accuracy: 0.000_001)
        XCTAssertNil(overlay.messageLabel.text)
        XCTAssertEqual(overlay.focusImageView?.alpha, focusAlpha)
    }

    @MainActor
    func testGuideButtonPresentsOriginalWebGuideInsteadOfFirstInstallAnimation() throws {
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

        let cameraSurface = try XCTUnwrap(
            camera.children.compactMap { $0 as? CameraViewController }.first
        )
        cameraSurface.onGuide?()
        let guide = try XCTUnwrap(camera.presentedViewController as? TTCameraGuideViewController)
        guide.loadViewIfNeeded()

        XCTAssertEqual(guide.modalPresentationStyle, .fullScreen)
        XCTAssertEqual(guide.view.accessibilityIdentifier, "aiscan.camera.guide-web")
        XCTAssertTrue(guide.view.subviews.contains { view in
            view.accessibilityIdentifier == "aiscan.camera.guide-web.content"
        })
        let webView = try XCTUnwrap(guide.view.subviews.compactMap { $0 as? WKWebView }.first)
        XCTAssertFalse(webView.configuration.websiteDataStore.isPersistent)
        XCTAssertFalse(
            cameraSurface.children.contains { $0 is PreviewGuideViewController }
        )
    }

    @MainActor
    func testClosingManualWebGuideRestartsPreparedCameraSession() async throws {
        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        context.displayMetadata = ["show_flash_warning": "false"]
        let camera = AIScanCameraViewController(cameraController: controller, context: context)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        for _ in 0..<20 where engine.startRunningCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(engine.startRunningCount, 1)
        // Hostless SwiftPM unit tests do not drive UIKit presentation
        // lifecycle callbacks, so model the full-screen transition explicitly.
        camera.beginAppearanceTransition(false, animated: false)
        camera.endAppearanceTransition()
        XCTAssertEqual(engine.stopRunningCount, 1)
        let cameraSurface = try XCTUnwrap(
            camera.children.compactMap { $0 as? CameraViewController }.first
        )
        cameraSurface.onGuide?()
        let guide = try XCTUnwrap(camera.presentedViewController as? TTCameraGuideViewController)
        guide.loadViewIfNeeded()

        _ = guide.perform(NSSelectorFromString("close:"), with: nil)
        for _ in 0..<40 where engine.startRunningCount < 2 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(engine.startRunningCount, 2)
    }

    func testOriginalWebGuideURLMatchesLegacyPartAndLocaleMapping() {
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        XCTAssertEqual(
            AIScanCameraGuideURL.make(context: context, languageCode: "ko")?.absoluteString,
            "https://resource-core.aiforpetcdn.com/sdk/guide/ko/dog/eye.html"
        )

        context.partType = .skin
        context.analysisPosition = "foot"
        XCTAssertEqual(
            AIScanCameraGuideURL.make(context: context, languageCode: "fr")?.absoluteString,
            "https://resource-core.aiforpetcdn.com/sdk/guide/en/dog/foot.html"
        )
    }

    func testWebGuideNavigationAllowsOnlyKnownHTTPSGuidePages() {
        XCTAssertTrue(AIScanCameraGuideNavigationPolicy.allows(
            URL(string: "https://resource-core.aiforpetcdn.com/sdk/guide/ko/dog/eye.html")
        ))
        XCTAssertTrue(AIScanCameraGuideNavigationPolicy.allows(
            URL(string: "https://resource-core.aiforpetcdn.com:443/sdk/guide/en/cat/tooth.html")
        ))

        let blocked = [
            "http://resource-core.aiforpetcdn.com/sdk/guide/ko/dog/eye.html",
            "https://resource-core.aiforpetcdn.com.example.com/sdk/guide/ko/dog/eye.html",
            "https://resource-core.aiforpetcdn.com/sdk/guide/ko/dog/eye.html?redirect=https://example.com",
            "https://resource-core.aiforpetcdn.com/sdk/guide/ko/dog/%2e%2e/eye.html",
            "https://user@resource-core.aiforpetcdn.com/sdk/guide/ko/dog/eye.html",
            "https://resource-core.aiforpetcdn.com/other/guide/ko/dog/eye.html",
        ]
        for value in blocked {
            XCTAssertFalse(
                AIScanCameraGuideNavigationPolicy.allows(URL(string: value)),
                value
            )
        }
    }

    @MainActor
    func testCaptureButtonDismissesInitialGuideAndStartsCaptureInTheSameTap() async throws {
        let defaultsKey = "com.aiforpet.didShowPreviewGuide.dog.eye"
        let savedGuideMarker = UserDefaults.standard.object(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer {
            if let savedGuideMarker {
                UserDefaults.standard.set(savedGuideMarker, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }

        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        context.displayMetadata = ["show_flash_warning": "false"]
        let camera = AIScanCameraViewController(cameraController: controller, context: context)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        let cameraSurface = try XCTUnwrap(
            camera.children.compactMap { $0 as? CameraViewController }.first
        )
        var guide: PreviewGuideViewController?
        for _ in 0..<20 where guide == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
            guide = cameraSurface.children
                .compactMap { $0 as? PreviewGuideViewController }
                .first
        }
        XCTAssertNotNil(guide)
        XCTAssertFalse(engine.automaticallyCapturesReadyFrames)

        cameraSurface.view.layoutIfNeeded()
        let capturePoint = cameraSurface.captureButton.convert(
            CGPoint(
                x: cameraSurface.captureButton.bounds.midX,
                y: cameraSurface.captureButton.bounds.midY
            ),
            to: window
        )
        let captureHitView = window.hitTest(capturePoint, with: nil)
        XCTAssertTrue(cameraSurface.captureButton.isEnabled)
        XCTAssertTrue(
            captureHitView === cameraSurface.captureButton
                || captureHitView?.isDescendant(of: cameraSurface.captureButton) == true,
            "The first-install guide must not intercept the original capture button."
        )

        cameraSurface.capture(cameraSurface.captureButton as Any)

        XCTAssertNil(
            cameraSurface.children.compactMap { $0 as? PreviewGuideViewController }.first
        )
        XCTAssertTrue(engine.automaticallyCapturesReadyFrames)
    }

    @MainActor
    func testAutomaticGuideDoesNotReappearAfterItsFirstPresentation() async throws {
        let defaultsKey = "com.aiforpet.didShowPreviewGuide.dog.eye"
        let savedGuideMarker = UserDefaults.standard.object(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer {
            if let savedGuideMarker {
                UserDefaults.standard.set(savedGuideMarker, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }

        func makeCamera(engine: MockCameraEngine) -> (AIScanCameraViewController, UIWindow) {
            engine.emitsPreparationProgress = false
            let controller = AIScanCameraController(cameraEngine: engine)
            let context = AISCScanContext()
            context.petType = .dog
            context.partType = .eye
            context.displayMetadata = ["show_flash_warning": "false"]
            let camera = AIScanCameraViewController(cameraController: controller, context: context)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = camera
            window.makeKeyAndVisible()
            camera.loadViewIfNeeded()
            return (camera, window)
        }

        let firstEngine = MockCameraEngine()
        let (firstCamera, firstWindow) = makeCamera(engine: firstEngine)
        let firstSurface = try XCTUnwrap(
            firstCamera.children.compactMap { $0 as? CameraViewController }.first
        )
        var firstGuide: PreviewGuideViewController?
        for _ in 0..<20 where firstGuide == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
            firstGuide = firstSurface.children
                .compactMap { $0 as? PreviewGuideViewController }
                .first
        }
        XCTAssertNotNil(firstGuide)
        XCTAssertEqual(UserDefaults.standard.object(forKey: defaultsKey) as? Bool, true)

        firstWindow.isHidden = true
        firstWindow.rootViewController = nil

        let secondEngine = MockCameraEngine()
        let (secondCamera, secondWindow) = makeCamera(engine: secondEngine)
        defer { secondWindow.isHidden = true }
        for _ in 0..<20 where secondEngine.startRunningCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let secondSurface = try XCTUnwrap(
            secondCamera.children.compactMap { $0 as? CameraViewController }.first
        )

        XCTAssertNil(
            secondSurface.children.compactMap { $0 as? PreviewGuideViewController }.first,
            "The automatic guide must stay dismissed until the app is reinstalled."
        )
    }

    @MainActor
    func testLegacyDailyGuideMarkerCountsAsAlreadyShownAfterUpgrade() async throws {
        let defaultsKey = "com.aiforpet.didShowPreviewGuide.dog.eye"
        let savedGuideMarker = UserDefaults.standard.object(forKey: defaultsKey)
        UserDefaults.standard.set("2000-01-01", forKey: defaultsKey)
        defer {
            if let savedGuideMarker {
                UserDefaults.standard.set(savedGuideMarker, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }

        let engine = MockCameraEngine()
        engine.emitsPreparationProgress = false
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        context.displayMetadata = ["show_flash_warning": "false"]
        let camera = AIScanCameraViewController(cameraController: controller, context: context)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        for _ in 0..<20 where engine.startRunningCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let cameraSurface = try XCTUnwrap(
            camera.children.compactMap { $0 as? CameraViewController }.first
        )

        XCTAssertEqual(engine.startRunningCount, 1)
        XCTAssertNil(
            cameraSurface.children.compactMap { $0 as? PreviewGuideViewController }.first,
            "Any existing guide marker must suppress the automatic guide for this installation."
        )
    }

    @MainActor
    func testOriginalPreviewGuideCopyIsRestored() {
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let guide = PreviewGuideViewController.instantiate(context: context)
        guide.loadViewIfNeeded()

        XCTAssertEqual(guide.messageLabel.text, AIScanCameraStrings.localized(.startPrompt))
        XCTAssertTrue(
            guide.view.allLabels.contains {
                $0.text == AIScanCameraStrings.localizedMessageKey("camera.guide.example")
            }
        )
    }

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
    func testDiagnosisProgressDisplaysTheAcceptedPreprocessCrop() throws {
        let progress = TTProgressViewController.instantiate()
        progress.loadViewIfNeeded()
        let image = UIImage(
            ciImage: CIImage(color: .red).cropped(
                to: CGRect(x: 0, y: 0, width: 96, height: 64)
            )
        )

        progress.set(previewImage: image)

        let imageView = try XCTUnwrap(progress.diagnosisImageView)
        XCTAssertIdentical(imageView.image, image)
        XCTAssertEqual(
            imageView.accessibilityIdentifier,
            "aiscan.camera.progress.preview"
        )
    }

    @MainActor
    func testOriginalDownloadProgressSceneAndCopyAreRestored() {
        let progress = TTProgressViewController.instantiateDownload()
        progress.loadViewIfNeeded()
        progress.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        progress.view.layoutIfNeeded()

        XCTAssertTrue(progress.isDownloadProgress)
        XCTAssertEqual(
            progress.view.accessibilityIdentifier,
            "aiscan.camera.download-progress"
        )
        XCTAssertEqual(
            progress.titleLabel.text,
            AIScanCameraStrings.localizedMessageKey("progress.download")
        )
        XCTAssertEqual(progress.view.backgroundColor, .black)
        XCTAssertEqual(progress.containerView.backgroundColor, .clear)
        XCTAssertEqual(progress.progressView?.progressTintColor, .white)
        XCTAssertEqual(progress.progressView?.trackTintColor, UIColor(named: "#353537", in: AIScanCameraResourceBundle.bundle, compatibleWith: nil))
        XCTAssertEqual(progress.progressView?.frame.width ?? 0, 220, accuracy: 0.5)
    }

    func testMedicalCertificationLanguageFollowsTheActiveUIResourceBundle() {
        let expectedLanguage = AIScanCameraResourceBundle.bundle.preferredLocalizations
            .first { $0.caseInsensitiveCompare("Base") != .orderedSame }?
            .lowercased() ?? "en"

        XCTAssertEqual(AIScanCameraStrings.currentLanguageCode, expectedLanguage)
        XCTAssertTrue(AIScanCameraStrings.isKoreanUI(languageCode: "ko"))
        XCTAssertTrue(AIScanCameraStrings.isKoreanUI(languageCode: "ko-KR"))
        XCTAssertFalse(AIScanCameraStrings.isKoreanUI(languageCode: "en"))
        XCTAssertFalse(AIScanCameraStrings.isKoreanUI(languageCode: "ja"))
    }

    @MainActor
    func testDownloadProgressDisplaysMeasuredSpeedAndPercentageLikeLegacy() throws {
        let progress = TTProgressViewController.instantiateDownload()
        progress.loadViewIfNeeded()

        progress.set(
            downloadProgress: AIScanPreparationProgressSnapshot(
                normalizedProgress: 0.42,
                bytesWritten: 42 * 1_024,
                totalBytes: 100 * 1_024,
                bytesPerSecond: 1.5 * 1_024 * 1_024
            ),
            animated: false
        )

        XCTAssertEqual(progress.subtitleLabel.text, "1.5 MB/s")
        let count = try XCTUnwrap(
            progress.view.descendant(
                accessibilityIdentifier: "aiscan.camera.download-progress.percent"
            ) as? UILabel
        )
        XCTAssertEqual(count.text, "42%")
        XCTAssertEqual(count.accessibilityValue, "42%")
    }

    @MainActor
    func testInjectedEngineForwardsPreparationDownloadProgress() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        var values: [Double] = []
        var preparationError: Error?

        controller.prepare(context: context, progress: { values.append($0) }) {
            preparationError = $0
        }

        XCTAssertEqual(values, [0.25, 1])
        XCTAssertNil(preparationError)
    }

    @MainActor
    func testInjectedEngineForwardsMeasuredPreparationDownloadProgress() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        var values: [AIScanPreparationProgressSnapshot] = []
        var preparationError: Error?

        controller.prepare(context: context, detailedProgress: { values.append($0) }) {
            preparationError = $0
        }

        XCTAssertEqual(values, [
            AIScanPreparationProgressSnapshot(
                normalizedProgress: 0.25,
                bytesWritten: 512,
                totalBytes: 2_048,
                bytesPerSecond: 1_536
            ),
            AIScanPreparationProgressSnapshot(
                normalizedProgress: 1,
                bytesWritten: 2_048,
                totalBytes: 2_048,
                bytesPerSecond: 4_096
            ),
        ])
        XCTAssertNil(preparationError)
    }

    @MainActor
    func testInjectedEngineOwnsControlCommands() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        var preparationError: Error?

        controller.automaticallyCapturesReadyFrames = true
        controller.prepare(context: context) { preparationError = $0 }
        controller.albumDidOpen()
        controller.albumDidCancel()
        controller.resultDidBecomeVisible()
        controller.resultDidShare()
        controller.captureNextFrame()
        controller.reset()
        controller.cancel()

        XCTAssertTrue(engine.automaticallyCapturesReadyFrames)
        XCTAssertIdentical(engine.preparedContexts.first, context)
        XCTAssertNil(preparationError)
        XCTAssertEqual(engine.albumOpenCount, 1)
        XCTAssertEqual(engine.albumCancelCount, 1)
        XCTAssertEqual(engine.resultVisibleCount, 1)
        XCTAssertEqual(engine.resultShareCount, 1)
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
        receivedAllEvents.expectedFulfillmentCount = 6
        var events: [String] = []
        probe.onEvent = {
            events.append($0)
            receivedAllEvents.fulfill()
        }

        let evaluation = makeEvaluation(captureAllowed: true)
        engine.emitFrame(evaluation)
        engine.emitCapture(evaluation)
        engine.emitPreview(
            CIImage(color: .red).cropped(
                to: CGRect(x: 37, y: 19, width: 8, height: 6)
            )
        )
        engine.emitProgress(0.42)
        engine.emitResult(AISCDisplayResult(status: "completed", diagnosisID: "dx-1", symptoms: []))
        engine.emitFailure(NSError(domain: AISCErrorDomain, code: 77))

        await fulfillment(of: [receivedAllEvents], timeout: 1)
        XCTAssertEqual(events, [
            "frame",
            "capture",
            "preview:8x6",
            "progress:0.42",
            "result:completed",
            "failure:77",
        ])
        XCTAssertNotNil(probe.previewImage?.cgImage)
        XCTAssertNil(probe.previewImage?.ciImage)
        XCTAssertEqual(probe.previewImage?.size, CGSize(width: 8, height: 6))
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

        camera.beginCaptureAttempt()
        engine.emitCapture(makeEvaluation(captureAllowed: true))
        let acceptedCrop = CIImage(color: .red).cropped(
            to: CGRect(x: 0, y: 0, width: 96, height: 64)
        )
        engine.emitPreview(acceptedCrop)
        engine.emitProgress(0.42)
        try await Task.sleep(nanoseconds: 100_000_000)

        let progressLabel = try XCTUnwrap(
            camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.progress.percent"
            ) as? UILabel
        )
        XCTAssertEqual(progressLabel.accessibilityValue, "42%")
        let preview = try XCTUnwrap(
            camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.progress.preview"
            ) as? UIImageView
        )
        XCTAssertNil(preview.image?.ciImage)
        XCTAssertEqual(preview.image?.cgImage?.width, Int(acceptedCrop.extent.width))
        XCTAssertEqual(preview.image?.cgImage?.height, Int(acceptedCrop.extent.height))

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

    @MainActor
    func testNonRetryableAppIdentityMismatchShowsCloseWithoutRetryAndFailsOnce() async throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let camera = AIScanCameraViewController(cameraController: controller, context: context)
        camera.beginsScanningAutomatically = false
        var failureCount = 0
        camera.onFailure = { _ in failureCount += 1 }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        let error = NSError(
            domain: AISCErrorDomain,
            code: 104,
            userInfo: [
                AISCRetryableKey: false,
                AISCDisplayReasonKey: "app_identity_mismatch"
            ]
        )
        engine.emitFailure(error)
        engine.emitFailure(error)

        var closeButton: UIView?
        for _ in 0..<20 where closeButton == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
            closeButton = camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.close"
            )
        }

        XCTAssertEqual(failureCount, 1)
        XCTAssertNotNil(closeButton)
        XCTAssertNil(
            camera.presentedViewController?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.retry"
            )
        )
    }

    @MainActor
    func testContractResultReturnsToHostWithoutForcingCameraStackDismissal() async throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .teeth
        context.analysisSubpart = "TCENTER"
        let stackDismisser = MockCameraStackDismisser()
        let surfaceCoordinator = MockTransientSurfaceCoordinator()
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: stackDismisser,
            transientSurfaceCoordinator: surfaceCoordinator
        )
        camera.beginsScanningAutomatically = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        camera.aiscanCameraController(
            controller,
            didCapture: makeEvaluation(captureAllowed: true)
        )
        XCTAssertNotNil(camera.presentedViewController)

        let completed = expectation(description: "contract result returned to host")
        completed.assertForOverFulfill = true
        var completionCount = 0
        camera.onResult = { _ in
            completionCount += 1
            completed.fulfill()
        }

        let result = AISCDisplayResult(
            status: "completed",
            diagnosisID: "dx-contract",
            symptoms: [],
            contractResult: AISCContractResult(
                schema: "ttcare.anomaly-check.v1",
                payload: ["status": "OK"]
            )
        )
        camera.aiscanCameraController(controller, didProduce: result)
        camera.aiscanCameraController(controller, didProduce: result)

        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(engine.resultVisibleCount, 0)
        XCTAssertEqual(engine.cancelCount, 0)
        XCTAssertEqual(stackDismisser.callCount, 0)
        XCTAssertEqual(surfaceCoordinator.dismissPresentedSurfaceCount, 1)
    }

    @MainActor
    func testCompletedDefaultResultClosesTheWholeStackAndCancelsCoreOnce() {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        let stackDismisser = MockCameraStackDismisser()
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: stackDismisser
        )
        camera.loadViewIfNeeded()

        camera.dismissCompletedScan()
        camera.dismissCompletedScan()

        XCTAssertEqual(stackDismisser.callCount, 1)
        XCTAssertEqual(engine.cancelCount, 1)
        XCTAssertEqual(
            stackDismisser.transitions,
            [.coordinatedCrossDissolve(duration: 0.2)]
        )
    }

    @MainActor
    func testTTAPIPreprocessRejectionKeepsCameraOpenAndShowsOriginalBottomRetakeSheet() async throws {
        let engine = MockCameraEngine()
        let controller = AIScanCameraController(cameraEngine: engine)
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .skin
        context.analysisPosition = "belly"
        let stackDismisser = MockCameraStackDismisser()
        let surfaceCoordinator = MockTransientSurfaceCoordinator()
        let camera = AIScanCameraViewController(
            cameraController: controller,
            context: context,
            stackDismisser: stackDismisser,
            transientSurfaceCoordinator: surfaceCoordinator
        )
        camera.beginsScanningAutomatically = false
        var resultCount = 0
        var failureCount = 0
        camera.onResult = { _ in resultCount += 1 }
        camera.onFailure = { _ in failureCount += 1 }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        camera.loadViewIfNeeded()

        camera.beginCaptureAttempt()
        camera.aiscanCameraController(
            controller,
            didCapture: makeEvaluation(captureAllowed: true)
        )
        camera.aiscanCameraController(controller, didCapturePreview: UIImage())
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = AISCDisplayResult(
            status: "completed",
            diagnosisID: "dx-preprocess-rejected",
            symptoms: [],
            contractResult: AISCContractResult(
                schema: "ttcare.anomaly-check.v1",
                payload: ["status": "ERROR"]
            ),
            requiresRetake: true,
            retakeReasonCode: "PRE_SKIN_CBLUR_NOT_OK"
        )
        camera.aiscanCameraController(controller, didProduce: result)

        var retakeView: UIView?
        for _ in 0..<30 where retakeView == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
            retakeView = surfaceCoordinator.presentedSurfaces.last?.view.descendant(
                accessibilityIdentifier: "aiscan.camera.retake"
            )
        }

        XCTAssertTrue(result.requiresRetake)
        XCTAssertNotNil(
            retakeView,
            "presented=\(String(describing: surfaceCoordinator.presentedSurfaces.last)) "
                + "window=\(String(describing: camera.viewIfLoaded?.window)) "
                + "phase should have routed to retake"
        )
        let popupContainer = try XCTUnwrap(surfaceCoordinator.presentedSurfaces.last)
        let popup = try XCTUnwrap(
            popupContainer.children.first as? TTPopupCheckedResultViewController
        )
        popupContainer.view.layoutIfNeeded()
        XCTAssertEqual(resultCount, 0)
        XCTAssertEqual(failureCount, 0)
        XCTAssertEqual(stackDismisser.callCount, 0)
        XCTAssertEqual(surfaceCoordinator.dismissPresentedSurfaceCount, 1)
        XCTAssertEqual(engine.cancelCount, 0)
        XCTAssertEqual(engine.startRunningCount, 1)
        XCTAssertEqual(popup.view.layer.cornerRadius, 33)
        XCTAssertEqual(popup.view.frame.maxY, window.bounds.maxY, accuracy: 0.5)
        XCTAssertEqual(popup.view.frame.height, 363, accuracy: 0.5)
        XCTAssertNotNil(
            popup.view.descendant(accessibilityIdentifier: "aiscan.camera.retake.captured") as? UIImageView
        )
        let referenceImage = try XCTUnwrap(
            popup.view.descendant(accessibilityIdentifier: "aiscan.camera.retake.reference") as? UIImageView
        )
        XCTAssertEqual(referenceImage.contentMode, .scaleAspectFill)
        XCTAssertTrue(referenceImage.clipsToBounds)
        let retakeLabels = popup.view.allLabels
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        XCTAssertTrue(retakeLabels.contains { label in
            label.text == AIScanCameraStrings.localized(.retakeTitle)
                || label.text == AIScanCameraStrings.localizedMessageKey("hold_still")
        })
        for label in retakeLabels where label.text?.isEmpty == false {
            XCTAssertNotEqual(
                label.textColor.resolvedColor(with: darkTraits),
                UIColor.black,
                "Retake popup labels must remain readable in dark mode"
            )
        }

        popup.confirm(popup.confirmButton as Any)
        for _ in 0..<30 where engine.resetCaptureAttemptCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(engine.resetCaptureAttemptCount, 1)
        XCTAssertEqual(surfaceCoordinator.dismissPopupCount, 1)
        XCTAssertFalse(engine.automaticallyCapturesReadyFrames)
        XCTAssertEqual(resultCount, 0)
        XCTAssertEqual(stackDismisser.callCount, 0)

        camera.beginCaptureAttempt()
        XCTAssertTrue(engine.automaticallyCapturesReadyFrames)
    }

    private func fontName(in label: UILabel) throws -> String {
        let attributedText = try XCTUnwrap(label.attributedText)
        let font = try XCTUnwrap(
            attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        )
        return font.fontName
    }

    private func assertOriginalPopupTypography(
        _ label: UILabel,
        pointSize: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let attributed = try XCTUnwrap(label.attributedText, file: file, line: line)
        let font = try XCTUnwrap(
            attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
            file: file,
            line: line
        )
        let paragraph = try XCTUnwrap(
            attributed.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                as? NSParagraphStyle,
            file: file,
            line: line
        )
        XCTAssertEqual(font.pointSize, pointSize, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(paragraph.lineSpacing, 5, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(
            attributed.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat,
            -0.5,
            file: file,
            line: line
        )
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

    var allLabels: [UILabel] {
        var labels = self is UILabel ? [self as! UILabel] : []
        labels.append(contentsOf: subviews.flatMap(\.allLabels))
        return labels
    }
}

import XCTest
import SwiftUI
import UIKit
import AIScan
@testable import AIScanCameraUI
@testable import AIScanReferenceUI

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

    func testPublicUILocalizationsPreserveApprovedKoreanLabels() {
        XCTAssertEqual(AIScanCameraStrings.localized(.capture, languageCode: "ko"), "촬영")
        XCTAssertEqual(AIScanCameraStrings.localized(.retry, languageCode: "ko"), "다시 시도")
        XCTAssertEqual(AIScanCameraStrings.localized(.close, languageCode: "ja"), "閉じる")
        XCTAssertEqual(AIScanReferenceStrings.localized(.originalPhoto, languageCode: "ko"), "원본 사진")
        XCTAssertEqual(AIScanReferenceStrings.localized(.analysisPhoto, languageCode: "ko"), "AI 분석 사진")
        XCTAssertEqual(AIScanReferenceStrings.localized(.analysisPhoto, languageCode: "en"), "AI analysis image")
        XCTAssertEqual(AIScanReferenceStrings.localized(.navigationTitle, languageCode: "ko"), "AI 건강 체크 결과")
        XCTAssertEqual(AIScanReferenceStrings.localized(.symptomDescriptionTitle, languageCode: "ko"), "이 증상은 무엇인가요")
        XCTAssertEqual(AIScanCameraStrings.localized(.flashRecommendationTitle, languageCode: "ko"), "플래시 사용을 권장해요")
        XCTAssertEqual(AIScanCameraStrings.localized(.start, languageCode: "ko"), "시작하기")
        XCTAssertEqual(AIScanCameraStrings.localized(.start, languageCode: "ja"), "始める")
        XCTAssertEqual(
            AIScanCameraStrings.localized(.flashRecommendationAction, languageCode: "ko"),
            "플래시를 사용하면 더 명확한\n결과를 제공해 드려요."
        )
        XCTAssertEqual(
            AIScanCameraStrings.localized(.flashRecommendationAction, languageCode: "en"),
            "Use flash for better\nresults."
        )
        XCTAssertEqual(
            AIScanCameraStrings.localized(.flashRecommendationBody, languageCode: "ko"),
            "일시적인 플래시 활성화가 동물에게 불편함을 유발할 순 있지만 건강상 위해를 미친다는 과학적 근거는 없어요. 불편함이 우려되면 플래시 입구에 얇은 종이를 덧대어주시면 도움이 될 수 있어요."
        )
        XCTAssertEqual(
            AIScanCameraStrings.localized(.flashRecommendationBody, languageCode: "en"),
            "Sudden use of flash can startle your pet. There is no scientific evidence that it harms them, but to avoid a glare you can cover the flash with a piece of paper."
        )
    }

    func testResultViewModelCarriesOnlyCompleteDisplaySafePresentationContent() {
        let section = AIScanDisplayDetailSection(
            id: "description",
            kind: .symptomDescription,
            title: "이 증상은 무엇인가요",
            lines: ["눈물이 과도하게 흘러 눈 주변이 계속 젖어 있는 상태예요."]
        )
        let symptom = AIScanDisplaySymptomViewModel(
            code: "tear",
            name: "유루증",
            abnormalLevel: 2,
            resultLabel: "주의 깊은 관찰이 필요해요",
            detailSections: [section]
        )
        let viewModel = AIScanDisplayResultViewModel(
            status: "WARNING",
            symptoms: [symptom],
            statusStyle: .warning,
            headline: "증상이 보여",
            subheadline: "주의 깊은 관찰이 필요해요",
            createdAtText: "2026. 07. 22 11:45"
        )

        XCTAssertEqual(viewModel.statusStyle, .warning)
        XCTAssertEqual(viewModel.headline, "증상이 보여")
        XCTAssertEqual(viewModel.subheadline, "주의 깊은 관찰이 필요해요")
        XCTAssertEqual(viewModel.createdAtText, "2026. 07. 22 11:45")
        XCTAssertEqual(viewModel.symptoms[0].detailSections, [section])
        XCTAssertEqual(
            Mirror(reflecting: section).children.compactMap(\.label),
            ["id", "kind", "title", "lines"]
        )
    }

    func testCameraErrorPresentationUsesOnlyApprovedDisplayReasons() {
        let internalError = NSError(
            domain: "AIScanCameraUI.AIScanCameraController",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "internal camera implementation detail"]
        )
        XCTAssertEqual(
            AIScanCameraStrings.displayMessage(for: internalError),
            AIScanCameraStrings.localized(.unavailable)
        )

        let approvedError = NSError(
            domain: "com.aiforpet.aiscan",
            code: -1,
            userInfo: [AISCDisplayReasonKey: "Approved display-safe reason"]
        )
        XCTAssertEqual(
            AIScanCameraStrings.displayMessage(for: approvedError),
            "Approved display-safe reason"
        )
        XCTAssertEqual(
            AIScanCameraStrings.displayMessage(
                for: AIScanCameraViewControllerError.cameraPermissionDenied
            ),
            AIScanCameraStrings.localized(.permissionDenied)
        )
    }

    func testReferenceThemePreservesLightPaletteAndUnselectedFrames() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)

        XCTAssertEqual(rgba(AIScanReferenceTheme.background.resolvedColor(with: light)), [255, 255, 255, 255])
        XCTAssertEqual(rgba(AIScanReferenceTheme.surfaceSecondary.resolvedColor(with: light)), [245, 246, 248, 255])
        XCTAssertEqual(rgba(AIScanReferenceTheme.textPrimary.resolvedColor(with: light)), [25, 25, 25, 255])
        XCTAssertEqual(AIScanReferenceTheme.unselectedChipBorderWidth, 1)
        XCTAssertNotEqual(
            rgba(AIScanReferenceTheme.unselectedChipBorder.resolvedColor(with: light)),
            rgba(AIScanReferenceTheme.background.resolvedColor(with: light))
        )
        XCTAssertNotEqual(
            rgba(AIScanReferenceTheme.surfaceSecondary.resolvedColor(with: dark)),
            [245, 246, 248, 255]
        )
    }

    @MainActor
    func testCameraChromeIsAccessibleAndFixedDarkWithoutStartingCapture() throws {
        let configuration = AISCConfiguration(publishableKey: "tt_pk_test_ui")
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .eye
        let camera = AIScanCameraViewController(configuration: configuration, context: context)
        camera.beginsScanningAutomatically = false
        camera.loadViewIfNeeded()

        XCTAssertEqual(camera.overrideUserInterfaceStyle, .dark)

        let status = try XCTUnwrap(
            camera.view.descendant(accessibilityIdentifier: "aiscan.camera.status") as? UILabel
        )
        let capture = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.capture"))
        let close = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.close"))
        let flash = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.flash"))
        let album = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.album"))
        let guide = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.guide"))
        let startPrompt = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.start-prompt"))
        let start = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.start"))
        let retry = try XCTUnwrap(camera.view.descendant(accessibilityIdentifier: "aiscan.camera.retry"))

        XCTAssertTrue(status.adjustsFontForContentSizeCategory)
        XCTAssertEqual(capture.accessibilityLabel, AIScanCameraStrings.localized(.capture))
        XCTAssertEqual(close.accessibilityLabel, AIScanCameraStrings.localized(.close))
        XCTAssertEqual(flash.accessibilityLabel, AIScanCameraStrings.localized(.flash))
        XCTAssertEqual(album.accessibilityLabel, AIScanCameraStrings.localized(.album))
        XCTAssertEqual(start.accessibilityLabel, AIScanCameraStrings.localized(.start))
        XCTAssertEqual(retry.accessibilityLabel, AIScanCameraStrings.localized(.retry))
        XCTAssertFalse(guide.isAccessibilityElement)
        XCTAssertFalse(startPrompt.isHidden)
        XCTAssertEqual(rgba(camera.view.backgroundColor ?? .clear), [0, 0, 0, 255])

        camera.overrideUserInterfaceStyle = .light
        XCTAssertEqual(rgba(camera.view.backgroundColor ?? .clear), [0, 0, 0, 255])
        camera.overrideUserInterfaceStyle = .dark
        XCTAssertEqual(rgba(camera.view.backgroundColor ?? .clear), [0, 0, 0, 255])
    }

    @MainActor
    func testReferenceResultRendersAtAccessibilityDynamicTypeInLightAndDark() {
        let viewModel = visualAuditResultViewModel()

        for style in [UIUserInterfaceStyle.light, .dark] {
            let view = AIScanResultReferenceView(viewModel: viewModel)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            let host = UIHostingController(rootView: view)
            host.overrideUserInterfaceStyle = style
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let renderer = UIGraphicsImageRenderer(bounds: host.view.bounds)
            let image = renderer.image { context in
                host.view.layer.render(in: context.cgContext)
            }
            XCTAssertNotNil(image.cgImage)
        }
    }

    @MainActor
    func testCapturePublicUIVisualAuditArtifacts() {
        let readyCameraLight = cameraSnapshot(style: .light, state: .ready)
        let readyCameraDark = cameraSnapshot(style: .dark, state: .ready)
        let errorCameraLight = cameraSnapshot(
            style: .light,
            state: .error(AIScanCameraStrings.localized(.permissionDenied))
        )
        let errorCameraDark = cameraSnapshot(
            style: .dark,
            state: .error(AIScanCameraStrings.localized(.permissionDenied))
        )

        XCTAssertEqual(readyCameraLight.pngData(), readyCameraDark.pngData())
        XCTAssertEqual(errorCameraLight.pngData(), errorCameraDark.pngData())
        attach(readyCameraLight, name: "01_camera_ready_light")
        attach(readyCameraDark, name: "01_camera_ready_dark")
        attach(errorCameraLight, name: "02_camera_error_retry_light")
        attach(errorCameraDark, name: "02_camera_error_retry_dark")

        for (style, suffix) in [
            (UIUserInterfaceStyle.light, "light"),
            (.dark, "dark"),
        ] {
            attach(
                resultSnapshot(style: style, sizeCategory: .large),
                name: "03_result_\(suffix)"
            )
            attach(
                resultSnapshot(style: style, sizeCategory: .accessibilityExtraExtraExtraLarge),
                name: "04_result_accessibility_\(suffix)"
            )
        }
    }

    @MainActor
    private func cameraSnapshot(
        style: UIUserInterfaceStyle,
        state: AIScanCameraPresentationState
    ) -> UIImage {
        let host = UIViewController()
        host.overrideUserInterfaceStyle = style
        host.view.backgroundColor = .black
        var chrome: AIScanCameraChromeView!
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            chrome = AIScanCameraChromeView()
        }
        chrome.overrideUserInterfaceStyle = .dark
        chrome.translatesAutoresizingMaskIntoConstraints = false
        chrome.apply(state: state)
        host.view.addSubview(chrome)
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: host.view.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            chrome.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
        ])
        return renderedStandaloneImage(of: host, style: style)
    }

    @MainActor
    private func resultSnapshot(
        style: UIUserInterfaceStyle,
        sizeCategory: ContentSizeCategory
    ) -> UIImage {
        let view = AIScanResultReferenceView(viewModel: visualAuditResultViewModel())
            .environment(\.sizeCategory, sizeCategory)
        let host = UIHostingController(rootView: view)
        return renderedImage(of: host, style: style)
    }

    private func visualAuditResultViewModel() -> AIScanDisplayResultViewModel {
        AIScanDisplayResultViewModel(
            status: "CAUTION",
            symptoms: [
                AIScanDisplaySymptomViewModel(
                    code: "tear",
                    name: "유루증",
                    abnormalLevel: 2,
                    resultLabel: "주의 깊은 관찰이 필요해요",
                    detailSections: [
                        AIScanDisplayDetailSection(
                            id: "description",
                            kind: .symptomDescription,
                            title: "이 증상은 무엇인가요",
                            lines: ["눈물이 과도하게 흘러 눈 주변이 계속 젖어 있는 상태예요. 눈 주변 털이 갈색이나 붉게 변할 수 있어요."]
                        ),
                        AIScanDisplayDetailSection(
                            id: "conditions",
                            kind: .relatedConditions,
                            title: "관련 질환 및 요인",
                            lines: ["각막염", "결막염", "비루관 폐색", "안검내반"]
                        ),
                        AIScanDisplayDetailSection(
                            id: "home-care",
                            kind: .homeCare,
                            title: "홈케어 시 주의사항",
                            lines: ["눈 주변을 청결하고 건조하게 관리해 주세요."]
                        )
                    ]
                ),
                AIScanDisplaySymptomViewModel(
                    code: "third-eyelid",
                    name: "제3안검돌출증",
                    abnormalLevel: 0,
                    resultLabel: "관찰되지 않아요"
                ),
                AIScanDisplaySymptomViewModel(
                    code: "chemosis",
                    name: "결막부종",
                    abnormalLevel: 0,
                    resultLabel: "관찰되지 않아요"
                ),
            ],
            statusStyle: .caution,
            headline: "증상이 보여",
            subheadline: "주의 깊은 관찰이 필요해요",
            createdAtText: "2026. 07. 22 11:45"
        )
    }

    @MainActor
    private func renderedImage(
        of viewController: UIViewController,
        style: UIUserInterfaceStyle
    ) -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let window = UIWindow(frame: frame)
        window.overrideUserInterfaceStyle = style
        viewController.overrideUserInterfaceStyle = style
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        viewController.view.frame = frame
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(bounds: frame, format: format).image { context in
            viewController.view.layer.render(in: context.cgContext)
        }
    }

    @MainActor
    private func renderedStandaloneImage(
        of viewController: UIViewController,
        style: UIUserInterfaceStyle
    ) -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.overrideUserInterfaceStyle = style
        viewController.view.frame = frame
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        viewController.view.subviews.forEach {
            $0.setNeedsLayout()
            $0.layoutIfNeeded()
            $0.setNeedsDisplay()
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(bounds: frame, format: format).image { context in
            viewController.view.layer.render(in: context.cgContext)
        }
    }

    private func attach(_ image: UIImage, name: String) {
        XCTAssertGreaterThan(image.pngData()?.count ?? 0, 1_000)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func rgba(_ color: UIColor) -> [Int] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return [red, green, blue, alpha].map { Int(round($0 * 255)) }
    }
}

private extension UIView {
    func descendant(accessibilityIdentifier: String) -> UIView? {
        if self.accessibilityIdentifier == accessibilityIdentifier {
            return self
        }
        return subviews.lazy.compactMap {
            $0.descendant(accessibilityIdentifier: accessibilityIdentifier)
        }.first
    }
}

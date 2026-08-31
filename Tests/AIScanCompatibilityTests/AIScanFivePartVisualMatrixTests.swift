import UIKit
import XCTest
import AIScanCore
@testable import AIScanCameraUI

final class AIScanFivePartVisualMatrixTests: XCTestCase {
    private struct VisualCase {
        let name: String
        let petType: AISCPetType
        let partType: AISCPartType
        let analysisPosition: String?
        let expectedOverlayType: TTOverlayViewController.Type
    }

    @MainActor
    func testFiveProductPathsAndEverySkinPositionRenderTheOriginalCameraSurface() throws {
        let cases: [VisualCase] = [
            .init(
                name: "dog_eye",
                petType: .dog,
                partType: .eye,
                analysisPosition: nil,
                expectedOverlayType: TTOverlayEyeViewController.self
            ),
            .init(
                name: "dog_teeth",
                petType: .dog,
                partType: .teeth,
                analysisPosition: nil,
                expectedOverlayType: TTOverlayToothViewController.self
            ),
            .init(
                name: "dog_skin_ear",
                petType: .dog,
                partType: .skin,
                analysisPosition: "ear",
                expectedOverlayType: TTOverlaySkinViewController.self
            ),
            .init(
                name: "dog_skin_belly",
                petType: .dog,
                partType: .skin,
                analysisPosition: "belly",
                expectedOverlayType: TTOverlaySkinViewController.self
            ),
            .init(
                name: "dog_skin_foot",
                petType: .dog,
                partType: .skin,
                analysisPosition: "foot",
                expectedOverlayType: TTOverlaySkinViewController.self
            ),
            .init(
                name: "cat_eye",
                petType: .cat,
                partType: .eye,
                analysisPosition: nil,
                expectedOverlayType: TTOverlayEyeViewController.self
            ),
            .init(
                name: "cat_teeth",
                petType: .cat,
                partType: .teeth,
                analysisPosition: nil,
                expectedOverlayType: TTOverlayToothViewController.self
            ),
        ]

        for item in cases {
            let context = AISCScanContext()
            context.petType = item.petType
            context.partType = item.partType
            context.analysisPosition = item.analysisPosition
            let configuration = AISCConfiguration(publishableKey: "tt_pk_test_visual_matrix")
            let camera = AIScanCameraViewController(
                configuration: configuration,
                context: context
            )
            camera.beginsScanningAutomatically = false

            let image = try renderPreparedCamera(
                camera,
                expectedOverlayType: item.expectedOverlayType,
                expectsPartSelector: false
            )
            let data = try XCTUnwrap(image.pngData())
            XCTAssertGreaterThan(data.count, 10_000, item.name)

            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "gap_zero_camera_\(item.name)_390x844"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testSelectableSkinCameraAndAreaPopupRenderAsACompleteFlow() throws {
        let context = AISCScanContext()
        context.petType = .dog
        context.partType = .skin
        let configuration = AISCConfiguration(publishableKey: "tt_pk_test_visual_matrix")
        let camera = AIScanCameraViewController(
            configuration: configuration,
            context: context
        )
        camera.beginsScanningAutomatically = false

        let cameraImage = try renderPreparedCamera(
            camera,
            expectedOverlayType: TTOverlaySkinViewController.self,
            expectsPartSelector: true
        )
        attach(cameraImage, name: "gap_zero_camera_dog_skin_select_390x844")

        let selector = TTPopupSelectedSkinViewController.instantiate(
            onStart: { _, _ in },
            onClose: {}
        )
        let popup = AIScanLegacyPopupContainer(content: selector, cardWidth: 316)
        let popupImage = render(popup)

        XCTAssertFalse(selector.startButton.isEnabled)
        XCTAssertEqual(selector.earContainer.layer.cornerRadius, 17)
        XCTAssertEqual(selector.bodyContainer.layer.cornerRadius, 17)
        XCTAssertEqual(selector.footContainer.layer.cornerRadius, 17)
        XCTAssertEqual(selector.view.bounds.width, 316, accuracy: 0.5)
        XCTAssertLessThanOrEqual(selector.view.frame.maxY, 844)
        XCTAssertGreaterThanOrEqual(selector.view.frame.minY, 0)
        attach(popupImage, name: "gap_zero_popup_dog_skin_area_select_390x844")
    }

    @MainActor
    func testAlbumEmptyStateRendersTheOriginalLightAndDarkSurface() throws {
        for (style, suffix) in [
            (UIUserInterfaceStyle.light, "light"),
            (.dark, "dark"),
        ] {
            let album = AIScanAlbumSelectionViewController(
                allowsPositionSelection: false,
                initialPosition: nil
            )
            let image = render(album, style: style)

            let card = try XCTUnwrap(album.view.descendant(
                accessibilityIdentifier: "aiscan.album.photo-card"
            ))
            let analyze = try XCTUnwrap(album.view.descendant(
                accessibilityIdentifier: "aiscan.album.analyze"
            ))
            XCTAssertEqual(card.bounds.height, 380, accuracy: 0.5)
            XCTAssertEqual(
                analyze.convert(analyze.bounds, to: album.view).maxY,
                album.view.safeAreaLayoutGuide.layoutFrame.maxY - 20,
                accuracy: 0.5
            )
            attach(image, name: "gap_zero_album_empty_\(suffix)_390x844")
        }
    }

    @MainActor
    func testCaptureFlowPopupsRenderTheOriginalLightAndDarkSurfaces() {
        for (style, suffix) in [
            (UIUserInterfaceStyle.light, "light"),
            (.dark, "dark"),
        ] {
            attach(
                renderPopup(
                    TTFlashWarningAlertViewController.instantiate(
                        showsSkinGuidance: false,
                        startsWithFlash: false,
                        onStart: { _ in }
                    ),
                    size: CGSize(width: 315, height: 520),
                    style: style
                ),
                name: "gap_zero_flash_popup_\(suffix)_390x844"
            )
            let skinSelector = TTPopupSelectedSkinViewController.instantiate(
                onStart: { _, _ in },
                onClose: {}
            )
            let skinSelectorImage = renderPopup(
                skinSelector,
                size: CGSize(width: 316, height: 650),
                style: style
            )
            assertCompleteSkinSelector(skinSelector, style: style)
            attach(
                skinSelectorImage,
                name: "gap_zero_skin_selection_popup_\(suffix)_390x844"
            )
            attach(
                renderPopup(
                    TTPopupTimeoverViewController.instantiate(
                        onRetry: {},
                        onGuide: {}
                    ),
                    size: CGSize(width: 315, height: 263),
                    style: style
                ),
                name: "gap_zero_timeover_popup_\(suffix)_390x844"
            )
        }
    }

    @MainActor
    func testAlertAndMultiReasonRetakeRenderTheOriginalLightAndDarkSurfaces() {
        for (style, suffix) in [
            (UIUserInterfaceStyle.light, "light"),
            (.dark, "dark"),
        ] {
            attach(
                renderPopup(
                    TTPopupAlertViewController.instantiate(
                        title: "사진을 다시 선택할까요?",
                        subtitle: "더 선명한 사진을 선택하면 분석 정확도를 높일 수 있어요.",
                        primaryTitle: "확인",
                        secondaryTitle: "취소",
                        layout: .horizontal,
                        onPrimary: nil,
                        onSecondary: nil
                    ),
                    size: CGSize(width: 315, height: 300),
                    style: style
                ),
                name: "gap_zero_alert_popup_\(suffix)_390x844"
            )
            attach(
                renderPopup(
                    TTPopupCheckedResultViewController.instantiate(
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
                    ),
                    size: CGSize(width: 378, height: 413),
                    style: style
                ),
                name: "gap_zero_checked_result_popup_\(suffix)_390x844"
            )
        }
    }

    @MainActor
    private func renderPreparedCamera(
        _ camera: AIScanCameraViewController,
        expectedOverlayType: TTOverlayViewController.Type,
        expectsPartSelector: Bool
    ) throws -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let window = UIWindow(frame: frame)
        window.rootViewController = camera
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        camera.loadViewIfNeeded()
        camera.view.frame = frame
        camera.view.setNeedsLayout()
        camera.view.layoutIfNeeded()

        let surface = try XCTUnwrap(
            camera.children.compactMap { $0 as? CameraViewController }.first
        )
        let overlay = try XCTUnwrap(
            surface.children.compactMap { $0 as? TTOverlayViewController }.first
        )
        XCTAssertTrue(type(of: overlay) == expectedOverlayType)

        surface.setPreparing(false)
        overlay.setCameraActive(true, animated: false)
        overlay.setMessage(AIScanCameraStrings.localized(.startPrompt))
        camera.view.setNeedsLayout()
        camera.view.layoutIfNeeded()

        XCTAssertEqual(camera.overrideUserInterfaceStyle, .dark)
        XCTAssertFalse(surface.captureButton.isHidden)
        XCTAssertTrue(surface.captureButton.isEnabled)
        XCTAssertEqual(
            surface.captureButton.layer.cornerRadius,
            surface.captureButton.bounds.width / 2,
            accuracy: 0.000_001
        )
        XCTAssertFalse(surface.guideButton.isHidden)
        XCTAssertEqual(surface.partSelectedContainer?.isHidden, !expectsPartSelector)
        XCTAssertFalse(overlay.messageContainer.isHidden)
        XCTAssertEqual(
            overlay.messageLabel.text,
            AIScanCameraStrings.localized(.startPrompt)
        )
        XCTAssertGreaterThan(overlay.focusContainer?.bounds.width ?? 0, 0)
        XCTAssertGreaterThan(overlay.focusContainer?.bounds.height ?? 0, 0)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(bounds: frame, format: format).image { context in
            camera.view.layer.render(in: context.cgContext)
        }
    }

    @MainActor
    private func render(
        _ viewController: UIViewController,
        style: UIUserInterfaceStyle = .dark
    ) -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let window = UIWindow(frame: frame)
        window.overrideUserInterfaceStyle = style
        viewController.overrideUserInterfaceStyle = style
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        viewController.loadViewIfNeeded()
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
    private func renderPopup(
        _ content: UIViewController,
        size: CGSize,
        style: UIUserInterfaceStyle
    ) -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let root = UIViewController()
        root.view.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        root.addChild(content)
        root.view.addSubview(content.view)
        content.didMove(toParent: root)
        content.view.frame = CGRect(
            x: (frame.width - size.width) / 2,
            y: (frame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        content.view.layer.cornerRadius = 33
        content.view.layer.masksToBounds = true
        return render(root, style: style)
    }

    private func attach(
        _ image: UIImage,
        name: String
    ) {
        let data = image.pngData()
        XCTAssertGreaterThan(data?.count ?? 0, 10_000, name)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func assertCompleteSkinSelector(
        _ selector: TTPopupSelectedSkinViewController,
        style: UIUserInterfaceStyle,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let requiredViews: [(String, UIView)] = [
            ("title", selector.titleLabel),
            ("ear", selector.earContainer),
            ("body", selector.bodyContainer),
            ("foot", selector.footContainer),
            ("flash", selector.flashContainer),
            ("flash description", selector.flashDescriptionLabel),
            ("warning", selector.warningLabel),
            ("description", selector.descriptionLabel),
            ("start", selector.startButton),
        ]
        let allowedBounds = selector.view.bounds.insetBy(dx: -0.5, dy: -0.5)
        for (name, view) in requiredViews {
            let frame = view.convert(view.bounds, to: selector.view)
            XCTAssertFalse(view.isHidden, "Missing skin popup \(name)", file: file, line: line)
            XCTAssertGreaterThan(view.alpha, 0, "Transparent skin popup \(name)", file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, "Zero-width skin popup \(name)", file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, "Zero-height skin popup \(name)", file: file, line: line)
            XCTAssertTrue(
                allowedBounds.contains(frame),
                "Skin popup \(name) is clipped: \(frame) outside \(selector.view.bounds)",
                file: file,
                line: line
            )
        }

        let traits = UITraitCollection(userInterfaceStyle: style)
        let titleColor = selector.titleLabel.textColor.resolvedColor(with: traits)
        let surfaceColor = selector.view.backgroundColor?.resolvedColor(with: traits)
        XCTAssertNotEqual(
            titleColor,
            surfaceColor,
            "Skin popup title is unreadable in \(style == .dark ? "dark" : "light") mode",
            file: file,
            line: line
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

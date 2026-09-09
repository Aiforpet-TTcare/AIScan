import XCTest
import UIKit
import AIScanCore
@testable import AIScanCameraUI

@MainActor
final class AIScanResultOriginalVisualParityTests: XCTestCase {
    private let screenSize = CGSize(width: 390, height: 844)

    func testQuestionnaireCautionRemainsADistinctDisplayStatus() {
        let display = AIScanDisplayResultViewModel(status: "CAUTION_Q")

        XCTAssertEqual(display.displayStatus, .cautionQuestionnaire)
        XCTAssertNotEqual(display.displayStatus, .caution)
    }

    func testQuestionnaireCautionRendersOriginalTitleAndDescription() throws {
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(status: "CAUTION_Q")
        )
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: screenSize)
        controller.view.layoutIfNeeded()

        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        collection.reloadData()
        collection.layoutIfNeeded()
        let titleCell = try XCTUnwrap(
            collection.dataSource?.collectionView(
                collection,
                cellForItemAt: IndexPath(item: 1, section: 0)
            ) as? AIScanResultTitleCell
        )
        let visibleLabels = allLabels(in: titleCell).filter { !$0.isHidden }

        XCTAssertEqual(
            visibleLabels.first?.text,
            AIScanReferenceStrings.localized(.cautionQuestionnaireHeadline)
        )
        XCTAssertEqual(
            visibleLabels.last?.text,
            AIScanReferenceStrings.localized(.cautionQuestionnaireDescription)
        )
        XCTAssertEqual(visibleLabels.last?.font.pointSize, 14)
        XCTAssertEqual(visibleLabels.last?.font.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func testDefaultResultUsesTheInjectedFlowDismissal() {
        var closeCount = 0
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(status: "NORMAL"),
            onClose: { closeCount += 1 }
        )

        XCTAssertNotNil(controller.onClose)
        controller.onClose?()

        XCTAssertEqual(closeCount, 1)
    }

    func testCoreSkinFeaturesMapToDisplayOnlyViewModel() {
        let features = AISCDisplaySkinFeatures(
            sensitivity: 2,
            dryness: 1,
            roughness: 3,
            total: 3
        )
        let result = AISCDisplayResult(
            status: "CAUTION",
            diagnosisID: "skin-1",
            symptoms: [],
            skinFeatures: features,
            contractResult: nil,
            requiresRetake: false,
            retakeReasonCode: nil,
            questionnaireAnswers: []
        )

        let display = AIScanDisplayResultViewModel(result: result)
        XCTAssertEqual(display.skinFeatures?.sensitivity, 2)
        XCTAssertEqual(display.skinFeatures?.dryness, 1)
        XCTAssertEqual(display.skinFeatures?.roughness, 3)
        XCTAssertEqual(display.skinFeatures?.total, 3)
    }

    func testCoreDiagnosisTimestampSurvivesTheDisplayBoundary() {
        let analyzedAt = Date(timeIntervalSince1970: 1_787_834_096)
        let result = AISCDisplayResult(
            status: "NORMAL",
            diagnosisID: "timestamp-result",
            symptoms: [],
            analyzedSymptoms: [],
            resultDetails: [],
            analyzedAt: analyzedAt,
            skinFeatures: nil,
            contractResult: nil,
            requiresRetake: false,
            retakeReasonCode: nil,
            questionnaireAnswers: []
        )

        let display = AIScanDisplayResultViewModel(result: result)

        XCTAssertEqual(display.analyzedAt, analyzedAt)
    }

    func testCoreCommonResultDetailsMapWithoutExposingCatalogLogicToUI() {
        let homeCare = AISCDisplayDetail(
            key: "home_care",
            title: "눈 – 홈케어 시 주의사항",
            contents: ["눈 주변을 깨끗하게 관리해 주세요."]
        )
        let analyzed = AISCDisplaySymptom(
            code: "opacity",
            name: "각막 혼탁",
            heatmapURL: URL(string: "https://cdn.test/heatmap"),
            cropImageURL: URL(string: "https://cdn.test/crop"),
            abnormalLevel: 0,
            resultLabel: "normal"
        )
        let result = AISCDisplayResult(
            status: "NORMAL",
            diagnosisID: "normal-result",
            symptoms: [],
            analyzedSymptoms: [analyzed],
            resultDetails: [homeCare],
            skinFeatures: nil,
            contractResult: nil,
            requiresRetake: false,
            retakeReasonCode: nil,
            questionnaireAnswers: []
        )

        let display = AIScanDisplayResultViewModel(result: result)

        XCTAssertEqual(display.resultDetails.count, 1)
        XCTAssertEqual(
            display.resultDetails.first?.text,
            "<b>눈 – 홈케어 시 주의사항</b><br>눈 주변을 깨끗하게 관리해 주세요."
        )
        XCTAssertEqual(display.analyzedSymptoms.first?.cropImageURL?.absoluteString,
                       "https://cdn.test/crop")
    }

    func testResultItemCombinesSymptomAndOriginalCommonGuidanceRows() throws {
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "CAUTION",
                symptoms: [
                    AIScanDisplaySymptomViewModel(
                        code: "opacity",
                        name: "각막 혼탁",
                        abnormalLevel: 1,
                        detailRows: [
                            AIScanDisplayDetailRowViewModel(
                                id: "what_it_is",
                                text: "<b>어떤 증상인가요?</b><br>각막이 뿌옇게 보여요."
                            )
                        ]
                    )
                ],
                resultDetails: [
                    AIScanDisplayDetailRowViewModel(
                        id: "vet_care",
                        text: "<b>동물병원 내원이 필요한 경우</b><br>증상이 지속되는 경우"
                    )
                ]
            )
        )
        controller.loadViewIfNeeded()
        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        let itemCell = try XCTUnwrap(
            collection.dataSource?.collectionView(
                collection,
                cellForItemAt: IndexPath(item: 6, section: 0)
            ) as? AIScanResultItemCell
        )
        let visibleText = allLabels(in: itemCell)
            .filter { !$0.isHidden }
            .compactMap { $0.attributedText?.string ?? $0.text }

        XCTAssertTrue(visibleText.contains { $0.contains("각막이 뿌옇게 보여요.") })
        XCTAssertTrue(visibleText.contains { $0.contains("증상이 지속되는 경우") })
    }

    func testResultDetailRowsKeepTheOriginalOrdinalIcons() throws {
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "CAUTION",
                symptoms: [
                    AIScanDisplaySymptomViewModel(
                        code: "opacity",
                        name: "각막 혼탁",
                        abnormalLevel: 1,
                        detailRows: (1...3).map {
                            AIScanDisplayDetailRowViewModel(text: "<b>row \($0)</b><br>body")
                        }
                    )
                ],
                resultDetails: [
                    AIScanDisplayDetailRowViewModel(text: "<b>row 4</b><br>body")
                ]
            )
        )
        controller.loadViewIfNeeded()
        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        let itemCell = try XCTUnwrap(
            collection.dataSource?.collectionView(
                collection,
                cellForItemAt: IndexPath(item: 6, section: 0)
            ) as? AIScanResultItemCell
        )
        let labels = allLabels(in: itemCell).filter {
            !$0.isHidden && ($0.attributedText?.string.contains("body") == true)
        }
        XCTAssertEqual(labels.count, 4)
        XCTAssertTrue(labels.allSatisfy { label in
            guard let value = label.attributedText else { return false }
            var containsAttachment = false
            value.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: value.length)
            ) { attachment, _, stop in
                if attachment != nil {
                    containsAttachment = true
                    stop.pointee = true
                }
            }
            return containsAttachment
        })
    }

    func testNormalResultUsesAnalyzedImageAndOriginalHomeCareRows() throws {
        let analyzed = AIScanDisplaySymptomViewModel(
            code: "opacity",
            name: "각막 혼탁",
            heatmapURL: URL(string: "https://cdn.test/heatmap"),
            cropImageURL: URL(string: "https://cdn.test/crop"),
            abnormalLevel: 0
        )
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "NORMAL",
                analyzedSymptoms: [analyzed],
                resultDetails: [
                    AIScanDisplayDetailRowViewModel(
                        id: "home_care",
                        text: "<b>홈케어</b><br>눈 주변을 깨끗하게 관리해 주세요."
                    )
                ]
            )
        )
        controller.loadViewIfNeeded()
        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        let itemCell = try XCTUnwrap(
            collection.dataSource?.collectionView(
                collection,
                cellForItemAt: IndexPath(item: 5, section: 0)
            ) as? AIScanResultItemCell
        )
        let visibleText = allLabels(in: itemCell)
            .filter { !$0.isHidden }
            .compactMap { $0.attributedText?.string ?? $0.text }

        XCTAssertTrue(visibleText.contains { $0.contains("눈 주변을 깨끗하게 관리해 주세요.") })
    }

    func testOnDeviceResultUsesExplicitSizingThroughInitialLayouts() throws {
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "NORMAL",
                analyzedSymptoms: [
                    AIScanDisplaySymptomViewModel(
                        code: "opacity",
                        name: "각막 혼탁",
                        abnormalLevel: 0
                    )
                ],
                resultDetails: [
                    AIScanDisplayDetailRowViewModel(
                        id: "home_care",
                        text: "<b>홈케어</b><br>눈 주변을 깨끗하게 관리해 주세요."
                    )
                ]
            )
        )
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: screenSize)

        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        let layout = try XCTUnwrap(
            collection.collectionViewLayout as? UICollectionViewFlowLayout
        )
        XCTAssertEqual(layout.estimatedItemSize, .zero)

        collection.reloadData()
        for _ in 0..<8 {
            controller.view.layoutIfNeeded()
            collection.layoutIfNeeded()
        }

        XCTAssertEqual(collection.numberOfItems(inSection: 0), 7)
        XCTAssertEqual(layout.estimatedItemSize, .zero)
        XCTAssertNotNil(collection.cellForItem(at: IndexPath(item: 5, section: 0)))
    }

    func testResultTabSelectionUpdatesDetailWithoutCollectionBatchReload() throws {
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "CAUTION",
                symptoms: [
                    AIScanDisplaySymptomViewModel(
                        code: "tear",
                        name: "유루증",
                        detailRows: [
                            AIScanDisplayDetailRowViewModel(
                                text: "<b>첫 번째</b><br>첫 번째 내용"
                            )
                        ]
                    ),
                    AIScanDisplaySymptomViewModel(
                        code: "chemosis",
                        name: "결막부종",
                        detailRows: [
                            AIScanDisplayDetailRowViewModel(
                                text: "<b>두 번째</b><br>두 번째 내용"
                            )
                        ]
                    )
                ]
            )
        )
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: screenSize)
        controller.view.layoutIfNeeded()

        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        collection.layoutIfNeeded()
        let tabCell = try XCTUnwrap(
            collection.cellForItem(at: IndexPath(item: 5, section: 0))
                as? AIScanResultTabCell
        )
        let tabs = try XCTUnwrap(findCollectionView(in: tabCell))
        tabs.delegate?.collectionView?(
            tabs,
            didSelectItemAt: IndexPath(item: 1, section: 0)
        )
        for _ in 0..<8 {
            controller.view.layoutIfNeeded()
            collection.layoutIfNeeded()
        }

        let itemCell = try XCTUnwrap(
            collection.cellForItem(at: IndexPath(item: 6, section: 0))
                as? AIScanResultItemCell
        )
        let visibleText = allLabels(in: itemCell)
            .filter { !$0.isHidden }
            .compactMap { $0.attributedText?.string ?? $0.text }
        XCTAssertTrue(visibleText.contains { $0.contains("두 번째\n두 번째 내용") })
    }

    func testSkinResultAppendsOriginalFeatureRowOnlyWhenPresent() throws {
        let withFeatures = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "NORMAL",
                skinFeatures: AIScanDisplaySkinFeaturesViewModel(
                    sensitivity: 0,
                    dryness: 0,
                    roughness: 0
                )
            )
        )
        withFeatures.loadViewIfNeeded()
        let collection = try XCTUnwrap(findCollectionView(in: withFeatures.view))
        XCTAssertEqual(collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0), 9)
        let cell = collection.dataSource?.collectionView(
            collection,
            cellForItemAt: IndexPath(item: 8, section: 0)
        )
        XCTAssertTrue(cell is AIScanSkinFeatureCell)
        XCTAssertEqual(cell?.accessibilityIdentifier, "aiscan.result.skin-features")

        let withoutFeatures = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(status: "NORMAL")
        )
        withoutFeatures.loadViewIfNeeded()
        let plainCollection = try XCTUnwrap(findCollectionView(in: withoutFeatures.view))
        XCTAssertEqual(plainCollection.dataSource?.collectionView(plainCollection, numberOfItemsInSection: 0), 7)
    }

    func testSkinFeatureOriginalLightAndDarkSnapshots() {
        let light = skinFeatureSnapshot(style: .light)
        let dark = skinFeatureSnapshot(style: .dark)
        AIScanVisualRegressionSupport.assertOriginalPixels(
            light,
            sha256: "3cdb35b15155712d77185feb249dca6d1f0f244222f318a0866298f6542f124e",
            name: "05_skin_features_light"
        )
        AIScanVisualRegressionSupport.assertOriginalPixels(
            dark,
            sha256: "5083a04ca3ccb4dd22b5d8b7f9b2883e62e82f156e7c95b1c8c19c7f59266013",
            name: "05_skin_features_dark"
        )
        attach(light, name: "05_skin_features_light_current")
        attach(dark, name: "05_skin_features_dark_current")
    }

    func testOriginalResultOverviewAndDetailSnapshots() {
        for (style, suffix) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
            let overview = resultOverviewSnapshot(style: style)
            let detail = resultDetailSnapshot(style: style)
            let overviewHash = suffix == "light"
                ? "91e00aae2d1c80440e2d55ef5ec23f6f04cda62bbba35633e27e6a20cf103b2f"
                : "563f869f91acd96a4ef072976e644804189a77e36113a29b4375cd933fc8d310"
            let detailHash = suffix == "light"
                ? "c463a14b0d561941afebd79d1ab11014f973259d36ced9825a10e68b72a7828a"
                : "6bd9f523f7bcf9043e643a707f9ab031cd754430502a88bc01c550847873c400"
            AIScanVisualRegressionSupport.assertOriginalPixels(
                overview,
                sha256: overviewHash,
                name: "03_sdk_result_overview_\(suffix)"
            )
            AIScanVisualRegressionSupport.assertOriginalPixels(
                detail,
                sha256: detailHash,
                name: "04_sdk_result_detail_\(suffix)"
            )
            attach(overview, name: "03_sdk_result_overview_\(suffix)_current")
            attach(detail, name: "04_sdk_result_detail_\(suffix)_current")
        }
    }

    func testOriginalSupportingControlSnapshots() {
        for (style, suffix) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
            let image = resultSupportingSnapshot(style: style)
            AIScanVisualRegressionSupport.assertOriginalPixels(
                image,
                sha256: suffix == "light"
                    ? "bbf664719e7903de3ab1cece7c89f1ee1ab77b8ff59f5c2408aaf13748dcc721"
                    : "55519a348980f8301a062ee6b53c4459cd01515649517be80d859e41281fd4b7",
                name: "11_sdk_supporting_controls_\(suffix)"
            )
            attach(
                image,
                name: "11_sdk_supporting_controls_\(suffix)_current"
            )
        }
    }

    func testPDFExportFooterIsOnlyExposedWithAWorkingAction() throws {
        var tapCount = 0
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(status: "NORMAL"),
            onExportReport: { tapCount += 1 }
        )
        controller.loadViewIfNeeded()
        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        collection.reloadData()
        collection.layoutIfNeeded()
        let layout = try XCTUnwrap(collection.collectionViewLayout as? UICollectionViewFlowLayout)
        XCTAssertEqual(layout.footerReferenceSize.height, 84)

        let footer = try XCTUnwrap(
            collection.dataSource?.collectionView?(
                collection,
                viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionFooter,
                at: IndexPath(item: 0, section: 0)
            ) as? AIScanPDFExportFooterView
        )
        XCTAssertNotNil(footer.onTap)
        footer.onTap?()
        XCTAssertEqual(tapCount, 1)

        tapCount = 0
        footer.onTap = { tapCount += 1 }
        let button = try XCTUnwrap(findButton(in: footer))
        XCTAssertEqual(button.accessibilityIdentifier, "aiscan.result.export-pdf")
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(tapCount, 1)

        controller.onExportReport = nil
        XCTAssertEqual(layout.footerReferenceSize.height, 0)
    }

    func testResultPlaceholderShipsTheOriginalVectorArtwork() throws {
        let image = try XCTUnwrap(
            UIImage(
                named: "checkResultEyeImgNo",
                in: AIScanReferenceStrings.resourceBundle,
                compatibleWith: nil
            )
        )
        XCTAssertEqual(image.size, CGSize(width: 57, height: 57))
    }

    func testEveryResultRowFitsStrictlyInsideTheFlowLayoutWithoutChangingRenderedPixels() throws {
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "CAUTION",
                symptoms: [
                    AIScanDisplaySymptomViewModel(
                        code: "tear",
                        name: "유루증",
                        detailRows: [AIScanDisplayDetailRowViewModel(text: "detail")]
                    )
                ],
                skinFeatures: AIScanDisplaySkinFeaturesViewModel(
                    sensitivity: 1,
                    dryness: 2,
                    roughness: 3
                )
            )
        )
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: screenSize)
        controller.view.layoutIfNeeded()

        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        collection.reloadData()
        collection.layoutIfNeeded()
        let count = try XCTUnwrap(
            collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0)
        )
        XCTAssertEqual(collection.bounds.width, screenSize.width)

        for item in 0..<count {
            let indexPath = IndexPath(item: item, section: 0)
            let cell = try XCTUnwrap(
                collection.dataSource?.collectionView(collection, cellForItemAt: indexPath)
            )
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.size = CGSize(width: collection.bounds.width, height: 50)
            let fitted = cell.preferredLayoutAttributesFitting(attributes)
            XCTAssertLessThan(
                fitted.size.width,
                collection.bounds.width,
                "row \(item) must satisfy UICollectionViewFlowLayout's strict width invariant"
            )
            XCTAssertEqual(
                fitted.size.width * UIScreen.main.scale,
                collection.bounds.width * UIScreen.main.scale,
                accuracy: 0.001,
                "the numerical guard must remain sub-pixel and preserve the original rendering"
            )
        }
    }

    private func resultOverviewSnapshot(style: UIUserInterfaceStyle) -> UIImage {
        let root = UIViewController()
        root.view.backgroundColor = AIScanReferenceTheme.background

        let title = UILabel(frame: CGRect(x: 64, y: 52, width: 262, height: 44))
        title.text = "AI 건강 체크 결과"
        title.textAlignment = .center
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = AIScanReferenceTheme.textPrimary
        root.view.addSubview(title)

        let status: AIScanResultStatusCell = instantiateCell("ResultStatusCell")
        add(status, to: root.view, frame: CGRect(x: 0, y: 118, width: 390, height: 130))

        let resultTitle: AIScanResultTitleCell = instantiateCell("ResultTitleCell")
        let resultTitleLabel = allLabels(in: resultTitle).first
        XCTAssertNotNil(resultTitleLabel)
        resultTitleLabel?.text = "증상이 보여\n주의 깊은 관찰이 필요해요"
        add(resultTitle, to: root.view, frame: CGRect(x: 0, y: 250, width: 390, height: 100))

        let date: AIScanResultDateCell = instantiateCell("ResultDateCell")
        let dateLabel = allLabels(in: date).first
        XCTAssertNotNil(dateLabel)
        dateLabel?.text = "2026. 07. 15 10:04"
        add(date, to: root.view, frame: CGRect(x: 0, y: 368, width: 390, height: 50))

        let tabs: AIScanResultTabCell = instantiateCell("ResultTabCell")
        add(tabs, to: root.view, frame: CGRect(x: 0, y: 448, width: 390, height: 64))
        return render(root, style: style)
    }

    private func resultDetailSnapshot(style: UIUserInterfaceStyle) -> UIImage {
        let root = UIViewController()
        root.view.backgroundColor = AIScanReferenceTheme.background
        let cell: AIScanResultItemCell = instantiateCell("ResultItemCell")
        // The archived original test resolves this host-demo asset as nil from
        // the framework bundle. Clear the SDK-owned copy for an exact render
        // comparison; its presence and original dimensions are tested above.
        allImageViews(in: cell).forEach { $0.image = nil }
        let detailTexts = [
            "이 증상은 무엇인가요\n눈물이 과도하게 흘러 눈 주변이 계속 젖어 있는 상태예요.",
            "관련 질환 및 요인\n각막염 · 결막염 · 비루관 폐색",
            "홈케어 시 주의사항\n눈 주변을 깨끗하게 관리해 주세요."
        ]
        let detailLabels = allLabels(in: cell).filter { $0.text == "정상" }
        XCTAssertEqual(detailLabels.count, 4)
        for (label, text) in zip(detailLabels, detailTexts) {
            label.text = text
        }
        add(cell, to: root.view, frame: CGRect(x: 0, y: 30, width: 390, height: 760))
        return render(root, style: style)
    }

    private func skinFeatureSnapshot(style: UIUserInterfaceStyle) -> UIImage {
        let root = UIViewController()
        root.view.backgroundColor = AIScanReferenceTheme.background
        let cell = AIScanSkinFeatureCell(frame: CGRect(x: 0, y: 180, width: 390, height: 300))
        cell.configure(
            items: [
                AIScanSkinFeatureItem(name: "민감도", value: 2, total: 3),
                AIScanSkinFeatureItem(name: "건조도", value: 1, total: 3),
                AIScanSkinFeatureItem(name: "거칠기", value: 3, total: 3)
            ],
            title: "피부 상태 상세"
        )
        cell.contentView.frame = cell.bounds
        root.view.addSubview(cell)
        return render(root, style: style)
    }

    private func resultSupportingSnapshot(style: UIUserInterfaceStyle) -> UIImage {
        let root = UIViewController()
        root.view.backgroundColor = AIScanReferenceTheme.background

        let notice: AIScanResultNoticeCell = instantiateCell("ResultNoticeCell")
        allLabels(in: notice).first?.text = "본 결과는 참고용이며 정확한 진단은 수의사와 상담해 주세요."
        add(notice, to: root.view, frame: CGRect(x: 0, y: 40, width: 390, height: 90))

        let footer = AIScanPDFExportFooterView(frame: CGRect(x: 0, y: 150, width: 390, height: 96))
        root.view.addSubview(footer)

        let indicator = TTIndicatorView(numberOfCircles: 4)
        indicator.frame.origin = CGPoint(x: 145, y: 300)
        indicator.updateIndicator(forPage: 1, animated: false)
        root.view.addSubview(indicator)

        let skeleton = AIScanSkeletonView(frame: CGRect(x: 20, y: 360, width: 350, height: 360))
        root.view.addSubview(skeleton)

        return render(root, style: style)
    }

    private func render(_ viewController: UIViewController, style: UIUserInterfaceStyle) -> UIImage {
        let window = UIWindow(frame: CGRect(origin: .zero, size: screenSize))
        window.overrideUserInterfaceStyle = style
        viewController.overrideUserInterfaceStyle = style
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        viewController.view.frame = window.bounds
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(bounds: viewController.view.bounds, format: format).image { context in
            viewController.view.layer.render(in: context.cgContext)
        }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func instantiateCell<T: UICollectionViewCell>(_ name: String) -> T {
        let nib = UINib(nibName: name, bundle: AIScanReferenceStrings.resourceBundle)
        return nib.instantiate(withOwner: nil).first as! T
    }

    private func add(_ cell: UICollectionViewCell, to parent: UIView, frame: CGRect) {
        cell.frame = frame
        cell.contentView.frame = cell.bounds
        parent.addSubview(cell)
    }

    private func allLabels(in view: UIView) -> [UILabel] {
        let own = (view as? UILabel).map { [$0] } ?? []
        return own + view.subviews.flatMap(allLabels(in:))
    }

    private func allImageViews(in view: UIView) -> [UIImageView] {
        let own = (view as? UIImageView).map { [$0] } ?? []
        return own + view.subviews.flatMap(allImageViews(in:))
    }

    private func findCollectionView(in view: UIView) -> UICollectionView? {
        if let collection = view as? UICollectionView { return collection }
        return view.subviews.lazy.compactMap(findCollectionView(in:)).first
    }

    private func findButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton { return button }
        return view.subviews.lazy.compactMap(findButton(in:)).first
    }

}

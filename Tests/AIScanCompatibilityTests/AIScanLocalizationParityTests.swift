import UIKit
import XCTest
import AIScanCore
@testable import AIScanCameraUI

final class AIScanLocalizationParityTests: XCTestCase {
    private let supportedLanguages = ["en", "it", "ja", "ko", "sv", "th"]

    func testEveryOriginalLanguageShipsTheSameCompleteUIKeySet() throws {
        let bundle = AIScanCameraResourceBundle.bundle
        let english = try stringsDictionary(
            table: "Localizable",
            language: "en",
            bundle: bundle
        )

        XCTAssertEqual(english.count, 98)
        for language in supportedLanguages {
            let localized = try stringsDictionary(
                table: "Localizable",
                language: language,
                bundle: bundle
            )
            XCTAssertEqual(
                Set(localized.keys),
                Set(english.keys),
                "\(language) must not add or omit UI localization keys."
            )
            for key in english.keys.sorted() {
                let value = localized[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(value?.isEmpty ?? true, "\(language) has an empty value for \(key).")
                let isKoreanSourceCopy = language == "ko"
                    && key.range(of: "[가-힣]", options: .regularExpression) != nil
                if !isKoreanSourceCopy {
                    XCTAssertNotEqual(value, key, "\(language) exposes the raw localization key \(key).")
                }
                XCTAssertFalse(value?.contains("__MISSING__") ?? false)
            }
        }
    }

    func testQuestionnaireCautionCopyMatchesTheOriginalSixLanguageContract() throws {
        let expectedTitles = [
            "en": "Please monitor closely.",
            "it": "Monitora con attenzione (questionario)",
            "ja": "注意深く観察してください。",
            "ko": "주의깊게 살펴봐 주세요.",
            "sv": "Håll noggrann uppsikt.",
            "th": "โปรดเฝ้าระวังอย่างใกล้ชิด",
        ]
        let expectedDescriptions = [
            "en": "The image looks normal, but based on the questionnaire, your pet may still be feeling discomfort or pain that isn't visible in photos. Please keep a close eye and consider a veterinary visit if needed.",
            "it": "L'immagine sembra normale, ma in base al questionario il tuo animale potrebbe comunque provare fastidio o dolore non visibile nelle foto. Tienilo sotto controllo e valuta una visita veterinaria, se necessario.",
            "ja": "写真では特別な異常は見られませんでしたが、問診の結果、写真では確認しづらいペットの不調や痛みが疑われます。動物病院への受診が必要になる場合もありますので、注意深く様子を観察してください。",
            "ko": "사진에서는 특별한 이상이 보이지 않았지만, 문진을 통해 사진으로는 확인하기 어려운 반려동물의 불편함이나 통증이 의심됩니다. 병원 방문이 필요할 수 있으니 주의 깊게 지켜봐 주세요.",
            "sv": "Bilden ser normal ut, men baserat på frågeformuläret kan ditt djur fortfarande känna obehag eller smärta som inte syns på foton. Håll noggrann uppsikt och överväg ett veterinärbesök vid behov.",
            "th": "ภาพดูปกติ แต่จากแบบสอบถาม สัตว์เลี้ยงของคุณอาจยังรู้สึกไม่สบายหรือเจ็บปวดที่มองไม่เห็นในภาพ โปรดเฝ้าดูอย่างใกล้ชิดและพิจารณาพาไปพบสัตวแพทย์หากจำเป็น",
        ]

        for language in supportedLanguages {
            XCTAssertEqual(
                AIScanReferenceStrings.localized(
                    .cautionQuestionnaireHeadline,
                    languageCode: language
                ),
                expectedTitles[language]
            )
            XCTAssertEqual(
                AIScanReferenceStrings.localized(
                    .cautionQuestionnaireDescription,
                    languageCode: language
                ),
                expectedDescriptions[language]
            )
        }
    }

    func testPDFLanguagePackMatchesTheOriginalSixLanguageContract() throws {
        let bundle = AIScanCameraResourceBundle.bundle
        let english = try stringsDictionary(
            table: "AIScanPDF",
            language: "en",
            bundle: bundle
        )

        XCTAssertEqual(english.count, 39)
        for language in supportedLanguages {
            let localized = try stringsDictionary(
                table: "AIScanPDF",
                language: language,
                bundle: bundle
            )
            XCTAssertEqual(
                Set(localized.keys),
                Set(english.keys),
                "\(language) PDF strings must match the original key set."
            )
            XCTAssertTrue(localized.values.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })
        }
    }

    func testPDFScreeningMessagesShipCompleteContentForAllSixLanguages() throws {
        let bundle = AIScanCameraResourceBundle.bundle
        let url = try XCTUnwrap(bundle.url(
            forResource: "screening_message",
            withExtension: "json"
        ))
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )

        var localizedSectionCount = 0
        assertCompleteLocalizedSections(
            in: root,
            path: [],
            localizedSectionCount: &localizedSectionCount
        )
        XCTAssertGreaterThan(localizedSectionCount, 0)
    }

    func testRestoredLanguagesDoNotSilentlyFallBackToEnglish() {
        let sentinels = [
            "camera.permission_denied",
            "popup.flash.subtitle",
            "popup.retake.title",
            "progress.download",
            "result.notice",
            "questionnaire.yes",
        ]

        for language in ["it", "sv", "th"] {
            for key in sentinels {
                XCTAssertNotEqual(
                    AIScanCameraStrings.localizedMessageKey(key, languageCode: language),
                    AIScanCameraStrings.localizedMessageKey(key, languageCode: "en"),
                    "\(language) silently falls back to English for \(key)."
                )
            }
        }
    }

    @MainActor
    func testCameraGuideCopyRemainsVisibleAcrossAllSixLanguages() throws {
        for language in supportedLanguages {
            let camera = CameraViewController.instantiate(partType: .eye)
            camera.loadViewIfNeeded()
            camera.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            camera.configureControls(showsPartSelector: false, showsGuide: true)
            camera.applyLocalizedCopy(languageCode: language)
            camera.view.layoutIfNeeded()

            let label = try XCTUnwrap(allLabels(in: camera.guideContainer).first)
            let required = label.sizeThatFits(
                CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)
            )
            XCTAssertFalse(label.isHidden, "\(language) guide copy is hidden.")
            XCTAssertGreaterThan(label.alpha, 0, "\(language) guide copy is transparent.")
            XCTAssertLessThanOrEqual(
                required.height,
                label.bounds.height + 1,
                "\(language) guide copy is vertically clipped."
            )
            if label.numberOfLines == 1 && !label.adjustsFontSizeToFitWidth {
                XCTAssertLessThanOrEqual(
                    label.intrinsicContentSize.width,
                    label.bounds.width + 1,
                    "\(language) guide copy is horizontally clipped."
                )
            }
        }
    }

    @MainActor
    func testProductionResultUsesTheSelectedLanguageWithoutClipping() throws {
        let controller = AIScanResultViewController.instance(
            viewModel: AIScanDisplayResultViewModel(
                status: "WARNING",
                skinFeatures: AIScanDisplaySkinFeaturesViewModel(
                    sensitivity: 2,
                    dryness: 1,
                    roughness: 3
                )
            ),
            onExportReport: {}
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()

        let title = try XCTUnwrap(controller.view.descendant(
            accessibilityIdentifier: "aiscan.result.navigation-title"
        ) as? UILabel)
        XCTAssertEqual(title.text, AIScanReferenceStrings.localized(.resultTitle))

        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        collection.reloadData()
        collection.layoutIfNeeded()
        let count = try XCTUnwrap(
            collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0)
        )
        for item in 0..<count {
            let indexPath = IndexPath(item: item, section: 0)
            let cell = try XCTUnwrap(
                collection.dataSource?.collectionView(collection, cellForItemAt: indexPath)
            )
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.size = CGSize(width: collection.bounds.width, height: 100)
            let fitted = cell.preferredLayoutAttributesFitting(attributes)
            cell.frame = CGRect(origin: .zero, size: fitted.size)
            cell.contentView.frame = cell.bounds
            cell.layoutIfNeeded()
            assertVisibleLabelsAreNotClipped(in: cell, context: "result row \(item)")
        }

        let attachment = XCTAttachment(string: AIScanCameraStrings.currentLanguageCode)
        attachment.name = "selected-language"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func stringsDictionary(
        table: String,
        language: String,
        bundle: Bundle
    ) throws -> [String: String] {
        let path = try XCTUnwrap(bundle.path(
            forResource: table,
            ofType: "strings",
            inDirectory: nil,
            forLocalization: language
        ))
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: String])
    }

    private func assertCompleteLocalizedSections(
        in object: [String: Any],
        path: [String],
        localizedSectionCount: inout Int
    ) {
        let presentLanguages = Set(object.keys).intersection(supportedLanguages)
        if !presentLanguages.isEmpty {
            localizedSectionCount += 1
            XCTAssertEqual(
                presentLanguages,
                Set(supportedLanguages),
                "Missing screening-message locale at \(path.joined(separator: "."))."
            )

            guard let english = object["en"] else { return }
            if let englishDictionary = english as? [String: Any] {
                let englishKeys = Set(englishDictionary.keys)
                for language in supportedLanguages {
                    guard let localized = object[language] as? [String: Any] else {
                        XCTFail("\(language) is not a dictionary at \(path.joined(separator: ".")).")
                        continue
                    }
                    XCTAssertEqual(
                        Set(localized.keys),
                        englishKeys,
                        "\(language) symptom keys differ at \(path.joined(separator: "."))."
                    )
                    for key in englishKeys {
                        let value = (localized[key] as? String)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        XCTAssertFalse(
                            value?.isEmpty ?? true,
                            "\(language) has empty screening copy at \((path + [key]).joined(separator: "."))."
                        )
                    }
                }
            } else {
                for language in supportedLanguages {
                    let value = (object[language] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    XCTAssertFalse(
                        value?.isEmpty ?? true,
                        "\(language) has empty screening copy at \(path.joined(separator: "."))."
                    )
                }
            }
        }

        for (key, value) in object {
            guard let child = value as? [String: Any] else { continue }
            assertCompleteLocalizedSections(
                in: child,
                path: path + [key],
                localizedSectionCount: &localizedSectionCount
            )
        }
    }

    @MainActor
    private func assertVisibleLabelsAreNotClipped(in view: UIView, context: String) {
        for label in allLabels(in: view) where !label.isHidden && label.alpha > 0 {
            guard let text = label.text, !text.isEmpty, label.bounds.width > 0 else { continue }
            let required = label.sizeThatFits(
                CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)
            )
            XCTAssertLessThanOrEqual(
                required.height,
                label.bounds.height + 1,
                "\(context) vertically clips \(text)."
            )
            if label.numberOfLines == 1 {
                let minimumScale = label.adjustsFontSizeToFitWidth
                    ? label.minimumScaleFactor
                    : 1
                XCTAssertLessThanOrEqual(
                    label.intrinsicContentSize.width * minimumScale,
                    label.bounds.width + 1,
                    "\(context) horizontally clips \(text)."
                )
            }
        }
    }

    @MainActor
    private func findCollectionView(in view: UIView) -> UICollectionView? {
        if let collection = view as? UICollectionView { return collection }
        return view.subviews.lazy.compactMap(findCollectionView(in:)).first
    }

    @MainActor
    private func allLabels(in view: UIView) -> [UILabel] {
        var labels = view is UILabel ? [view as! UILabel] : []
        for child in view.subviews {
            labels.append(contentsOf: allLabels(in: child))
        }
        return labels
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

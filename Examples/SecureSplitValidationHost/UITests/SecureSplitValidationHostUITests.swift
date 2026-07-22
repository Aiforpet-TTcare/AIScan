import XCTest

final class SecureSplitValidationHostUITests: XCTestCase {
    func testKoreanLightResultScreenshot() {
        captureResult(
            appearance: "light",
            language: "ko",
            locale: "ko_KR",
            attachmentName: "device_result_ko_light"
        )
    }

    func testKoreanDarkResultScreenshot() {
        captureResult(
            appearance: "dark",
            language: "ko",
            locale: "ko_KR",
            attachmentName: "device_result_ko_dark"
        )
    }

    func testEnglishLightResultScreenshot() {
        captureResult(
            appearance: "light",
            language: "en",
            locale: "en_US",
            attachmentName: "device_result_en_light"
        )
    }

    func testJapaneseLightResultScreenshot() {
        captureResult(
            appearance: "light",
            language: "ja",
            locale: "ja_JP",
            attachmentName: "device_result_ja_light"
        )
    }

    private func captureResult(
        appearance: String,
        language: String,
        locale: String,
        attachmentName: String
    ) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--show-result",
            "--appearance", appearance,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ]
        app.launch()

        let root = app.scrollViews["aiscan.result.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["aiscan.result.symptom.third-eyelid"].exists)
        XCTAssertTrue(app.buttons["aiscan.result.symptom.chemosis"].exists)

        let expectedCaptions: (original: String, analysis: String)
        switch language {
        case "ko":
            expectedCaptions = ("원본 사진", "AI 분석 사진")
        case "ja":
            expectedCaptions = ("元の写真", "AI分析画像")
        default:
            expectedCaptions = ("Original photo", "AI analysis image")
        }
        XCTAssertTrue(app.staticTexts[expectedCaptions.original].exists)
        XCTAssertTrue(app.staticTexts[expectedCaptions.analysis].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import UIKit
import XCTest
@testable import AIScanCameraUI

@MainActor
final class AIScanRetryButtonLayoutTests: XCTestCase {
    private let languages = ["ko", "en", "ja", "it", "sv", "th"]

    func testRetakeButtonsKeepBalancedPaddingInEveryLanguage() throws {
        for width: CGFloat in [308, 378] {
            for language in languages {
                let popup = TTPopupCheckedResultViewController.instantiate(
                    item: AIScanRetakeGuideItem(title: "Photo", wrongTitle: "", rightTitle: "", wrongImage: nil, rightImage: nil),
                    onRetake: {})
                popup.loadViewIfNeeded()
                popup.confirmButton.setTitle(AIScanCameraStrings.localized(.retakeAction, languageCode: language), for: .normal)
                layout(popup, width: width, height: 363)
                try assertPadding(popup.confirmButton, context: "retake \(language) \(width)")
                XCTAssertLessThanOrEqual(popup.confirmButton.bounds.width, width - 40 + 1)
                attach(popup, name: "retry-retake-\(language)-\(Int(width))")
            }
        }
    }

    func testAlertAndTimeoverRetryButtonsKeepPaddingInEveryLanguage() throws {
        for width: CGFloat in [288, 315] {
            for language in languages {
                for horizontal in [false, true] {
                    let popup = TTPopupAlertViewController.instantiate(title: "Photo", primaryTitle: AIScanCameraStrings.localized(.retry, languageCode: language),
                        secondaryTitle: AIScanCameraStrings.localized(.close, languageCode: language),
                        layout: horizontal ? .horizontal : .vertical, onPrimary: nil, onSecondary: nil)
                    layout(popup, width: width, height: 300)
                    try assertPadding(popup.confirmButton, context: "alert \(horizontal) \(language) \(width)")
                    if horizontal { try assertPadding(popup.cancelButton, context: "close \(language)") }
                }
                let popup = TTPopupTimeoverViewController.instantiate(onRetry: {}, onGuide: {})
                popup.loadViewIfNeeded()
                popup.confirmButton.setTitle(AIScanCameraStrings.localized(.timeoverRetry, languageCode: language), for: .normal)
                layout(popup, width: width, height: 380)
                try assertPadding(popup.confirmButton, context: "timeover \(language) \(width)")
            }
        }
    }

    private func layout(_ popup: UIViewController, width: CGFloat, height: CGFloat) {
        popup.loadViewIfNeeded()
        popup.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        popup.view.setNeedsLayout()
        popup.view.layoutIfNeeded()
    }

    private func assertPadding(_ button: UIButton, context: String, file: StaticString = #filePath, line: UInt = #line) throws {
        button.layoutIfNeeded()
        let label = try XCTUnwrap(button.titleLabel)
        let left = label.frame.minX
        let right = button.bounds.maxX - label.frame.maxX
        print("RETRY_LAYOUT \(context) button=\(button.bounds) title=\(label.frame) left=\(left) right=\(right)")
        XCTAssertGreaterThanOrEqual(left, 15.5, context, file: file, line: line)
        XCTAssertGreaterThanOrEqual(right, 15.5, context, file: file, line: line)
        XCTAssertEqual(left, right, accuracy: 1, context, file: file, line: line)
        XCTAssertLessThanOrEqual(label.frame.maxY, button.bounds.maxY, context, file: file, line: line)
        XCTAssertGreaterThanOrEqual(label.frame.minY, 0, context, file: file, line: line)
    }

    private func attach(_ popup: UIViewController, name: String) {
        let image = UIGraphicsImageRenderer(bounds: popup.view.bounds).image { popup.view.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

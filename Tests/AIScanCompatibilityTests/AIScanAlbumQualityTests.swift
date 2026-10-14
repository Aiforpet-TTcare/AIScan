import UIKit
import XCTest
import AIScanCore
import ImageIO
@testable import AIScanCameraUI

@MainActor
final class AIScanAlbumQualityTests: XCTestCase {
    private func photo(width: Int = 1200, height: Int = 1200) throws -> AIScanAlbumPhoto {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return try XCTUnwrap(AIScanAlbumPhoto(data: renderer.jpegData(withCompressionQuality: 0.9) {
            UIColor.brown.setFill(); $0.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }))
    }

    func testJPEGSourceIs24BitsEvenIfDecoderUses32BitStorage() throws {
        let selected = try photo()
        XCTAssertEqual(selected.metadata.bitsPerPixel, 24)
        XCTAssertTrue(AIScanAlbumQualityReport(metadata: selected.metadata, part: .skin).isValid)
    }

    func testIndexedPNGRemainsLowBitsAfterDecoding() throws {
        let palette: [UInt8] = [0, 0, 0, 255, 0, 0]
        let color = try XCTUnwrap(palette.withUnsafeBufferPointer {
            CGColorSpace(indexedBaseSpace: CGColorSpaceCreateDeviceRGB(), last: 1, colorTable: $0.baseAddress!)
        })
        let data = Data(repeating: 1, count: 1200 * 1200)
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let image = try XCTUnwrap(CGImage(width: 1200, height: 1200, bitsPerComponent: 8,
            bitsPerPixel: 8, bytesPerRow: 1200, space: color, bitmapInfo: [], provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let encoded = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let selected = try XCTUnwrap(AIScanAlbumPhoto(data: encoded as Data))
        XCTAssertLessThanOrEqual(try XCTUnwrap(selected.metadata.bitsPerPixel), 8)
        XCTAssertFalse(AIScanAlbumQualityReport(metadata: selected.metadata, part: .skin).isValid)
    }

    func testHEICSourceMetadataIsReadWithoutTreatingFileSizeAsBits() throws {
        let source = try photo()
        let encoded = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, "public.heic" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(source.image.cgImage), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let selected = try XCTUnwrap(AIScanAlbumPhoto(data: encoded as Data))
        XCTAssertEqual(selected.metadata.width, 1200)
        XCTAssertEqual(selected.metadata.height, 1200)
        XCTAssertEqual(selected.metadata.bitsPerPixel, 24)
    }

    func testEyeAnalysisStaysDisabledUntilBothDetectionAxesPass() throws {
        let album = AIScanAlbumSelectionViewController(allowsPositionSelection: false, initialPosition: nil, partType: .eye)
        album.loadViewIfNeeded()
        var finish: ((AIScanAlbumQualityReport) -> Void)?
        let selected = try photo()
        album.onInspect = { _, completion in finish = completion }
        album.applySelectedPhoto(selected)
        let analyze = try XCTUnwrap(find(album.view, "aiscan.album.analyze") as? UIButton)
        XCTAssertFalse(analyze.isEnabled)
        try XCTUnwrap(finish)(AIScanAlbumQualityReport(metadata: selected.metadata, part: .eye).measured(CGSize(width: 400, height: 100)))
        XCTAssertFalse(analyze.isEnabled)
        let low = try XCTUnwrap(find(album.view, "aiscan.album.quality.detect_height") as? UILabel)
        XCTAssertEqual(low.textColor, .systemRed)
        XCTAssertTrue(low.text?.contains("100 px") == true)
        let background = try XCTUnwrap(analyze.layer.sublayers?.first {
            $0.name == "aiscan.album.analyze-background"
        } as? CAShapeLayer)
        XCTAssertEqual(background.fillColor, AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.disabledSurface, traits: album.traitCollection
        ), "A rejected image must visibly disable the analysis action.")
        album.applySelectedPhoto(selected)
        try XCTUnwrap(finish)(AIScanAlbumQualityReport(metadata: selected.metadata, part: .eye).measured(CGSize(width: 270, height: 270)))
        XCTAssertTrue(analyze.isEnabled)
    }

    func testOldInspectionCannotApproveANewerPhoto() throws {
        let album = AIScanAlbumSelectionViewController(allowsPositionSelection: false, initialPosition: nil, partType: .eye)
        album.loadViewIfNeeded()
        var finish: ((AIScanAlbumQualityReport) -> Void)?
        album.onInspect = { _, completion in finish = completion }
        let selected = try photo()
        album.applySelectedPhoto(selected)
        let old = try XCTUnwrap(finish)
        album.applySelectedPhoto(try photo(width: 899, height: 1200))
        old(AIScanAlbumQualityReport(metadata: selected.metadata, part: .eye).measured(CGSize(width: 400, height: 400)))
        XCTAssertEqual(album.qualityReport?.metadata.width, 899)
        XCTAssertFalse(try XCTUnwrap(find(album.view, "aiscan.album.analyze") as? UIButton).isEnabled)
    }

    func testInspectionCompletingAfterCloseCannotEnableAnalysis() throws {
        let album = AIScanAlbumSelectionViewController(allowsPositionSelection: false, initialPosition: nil, partType: .eye)
        album.loadViewIfNeeded()
        var finish: ((AIScanAlbumQualityReport) -> Void)?
        album.onInspect = { _, completion in finish = completion }
        let selected = try photo()
        album.applySelectedPhoto(selected)
        let close = try XCTUnwrap(find(album.view, "aiscan.album.close") as? UIButton)
        var didClose = false
        album.onClose = { didClose = true }
        let action = try XCTUnwrap(close.actions(forTarget: album, forControlEvent: .touchUpInside)?.first)
        // This package test has no app event loop; invoke the button's registered target.
        _ = album.perform(NSSelectorFromString(action))
        XCTAssertTrue(didClose)
        try XCTUnwrap(finish)(AIScanAlbumQualityReport(metadata: selected.metadata, part: .eye).measured(CGSize(width: 400, height: 400)))
        XCTAssertFalse(try XCTUnwrap(find(album.view, "aiscan.album.analyze") as? UIButton).isEnabled)
    }

    func testQualityMeasurementsRemainScrollableOnSmallPhone() throws {
        let album = AIScanAlbumSelectionViewController(allowsPositionSelection: false, initialPosition: nil, partType: .teeth)
        album.loadViewIfNeeded()
        album.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        album.applySelectedPhoto(try photo(width: 1399, height: 1400))
        album.view.layoutIfNeeded()
        let label = try XCTUnwrap(find(album.view, "aiscan.album.quality.width") as? UILabel)
        XCTAssertEqual(label.textColor, .systemRed)
        XCTAssertTrue(label.text?.contains("1399 px") == true)
        let scroll = try XCTUnwrap(album.view.subviews.first { $0 is UIScrollView } as? UIScrollView)
        XCTAssertGreaterThanOrEqual(scroll.contentSize.height, scroll.bounds.height)
        let lastRow = try XCTUnwrap(find(album.view, "aiscan.album.quality.detect_height"))
        XCTAssertLessThanOrEqual(lastRow.convert(lastRow.bounds, to: scroll).maxY, scroll.contentSize.height)
        let image = UIGraphicsImageRenderer(bounds: album.view.bounds).image { album.view.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "album-quality-small-phone"
        attachment.lifetime = .keepAlways
        add(attachment)
        album.view.frame.size.height = 320
        album.view.setNeedsLayout()
        album.view.layoutIfNeeded()
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height, "A short viewport must scroll instead of clipping metrics.")
    }
    func testPartSpecificOriginalResolutionBoundaries() {
        for (part, minimum) in [(AISCPartType.skin, 1200), (.eye, 900), (.teeth, 1400)] {
            let valid = AIScanAlbumMetadata(width: minimum, height: minimum, bitsPerPixel: 24)
            XCTAssertTrue(AIScanAlbumQualityReport(metadata: valid, part: part).originalIsValid)
            for size in [(minimum - 1, minimum), (minimum, minimum - 1)] {
                let low = AIScanAlbumMetadata(width: size.0, height: size.1, bitsPerPixel: 24)
                XCTAssertFalse(AIScanAlbumQualityReport(metadata: low, part: part).originalIsValid)
            }
        }
    }

    func testDetectedWidthAndHeightAreIndependentAndNotUpscaled() {
        let metadata = AIScanAlbumMetadata(width: 2000, height: 2000, bitsPerPixel: 24)
        for (part, minimum) in [(AISCPartType.eye, 270), (.teeth, 400)] {
            let report = AIScanAlbumQualityReport(metadata: metadata, part: part)
            XCTAssertFalse(report.isValid)
            XCTAssertTrue(report.measured(CGSize(width: minimum, height: minimum)).isValid)
            XCTAssertFalse(report.measured(CGSize(width: minimum - 1, height: minimum)).isValid)
            XCTAssertFalse(report.measured(CGSize(width: minimum, height: minimum - 1)).isValid)
            XCTAssertFalse(report.measured(CGSize(width: CGFloat.nan, height: CGFloat(minimum))).isValid)
        }
    }

    func testUnknownAndInsufficientSourceBitsNeverPass() {
        for bits in [nil, 4, 8, 16, 23] as [Int?] {
            let metadata = AIScanAlbumMetadata(width: 1200, height: 1200, bitsPerPixel: bits)
            XCTAssertFalse(AIScanAlbumQualityReport(metadata: metadata, part: .skin).isValid)
        }
        for bits in [24, 32, 48] {
            let metadata = AIScanAlbumMetadata(width: 1200, height: 1200, bitsPerPixel: bits)
            XCTAssertTrue(AIScanAlbumQualityReport(metadata: metadata, part: .skin).isValid)
        }
    }

    func testPNGMetadataComesFromFileAndNotDecodedRGBAStorage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1200), format: format)
        let data = renderer.pngData { _ in UIColor.red.setFill(); UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1200, height: 1200)).fill() }
        let photo = try XCTUnwrap(AIScanAlbumPhoto(data: data))
        XCTAssertEqual(photo.metadata.width, 1200)
        XCTAssertEqual(photo.metadata.height, 1200)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(photo.metadata.bitsPerPixel), 24)
        let unknown = AIScanAlbumPhoto(image: photo.image)
        XCTAssertNil(unknown.metadata.bitsPerPixel)
        XCTAssertFalse(AIScanAlbumQualityReport(metadata: unknown.metadata, part: .skin).isValid)
    }

    func testApplePNGPrefixDoesNotShiftTheSourceBitDepthReading() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1200), format: format).pngData {
            UIColor.brown.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 1200, height: 1200))
        }
        // Apple's PNG optimizer inserts CgBI before IHDR. No animal photo is embedded.
        let prefix = Data([0, 0, 0, 4, 67, 103, 66, 73, 80, 0, 32, 6, 44, 184, 119, 102])
        var data = Data(source.prefix(8))
        data.append(prefix)
        data.append(source.dropFirst(8))
        let metadata = try XCTUnwrap(AIScanAlbumMetadata(data: data))
        XCTAssertEqual(metadata.width, 1200)
        XCTAssertEqual(metadata.height, 1200)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(metadata.bitsPerPixel), 24)
    }

    func testSkinDoesNotRequireSubjectDetection() {
        let metadata = AIScanAlbumMetadata(width: 1200, height: 1200, bitsPerPixel: 24)
        XCTAssertTrue(AIScanAlbumQualityReport(metadata: metadata, part: .skin).isValid)
    }
    private func find(_ view: UIView, _ identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        return view.subviews.lazy.compactMap { self.find($0, identifier) }.first
    }

    func testSmallSelectedPhotoCannotStartAnalysis() throws {
        let album = AIScanAlbumSelectionViewController(
            allowsPositionSelection: true, initialPosition: "belly"
        )
        album.loadViewIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image {
            UIColor.brown.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        album.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [
            .originalImage: image,
        ])
        let analyze = try XCTUnwrap(find(album.view, "aiscan.album.analyze") as? UIButton)
        XCTAssertFalse(analyze.isEnabled, "A low-resolution album photo must not start diagnosis.")
    }

    func testAlbumExposesQualityMeasurements() throws {
        let album = AIScanAlbumSelectionViewController(
            allowsPositionSelection: true, initialPosition: "belly"
        )
        album.loadViewIfNeeded()
        XCTAssertNotNil(find(album.view, "aiscan.album.quality"))
    }

    func testSmallPhotoShowsWhatToDoBeforeTheTechnicalMeasurements() throws {
        let album = AIScanAlbumSelectionViewController(allowsPositionSelection: false, initialPosition: nil, partType: .eye)
        album.loadViewIfNeeded()
        album.applySelectedPhoto(try photo(width: 400, height: 400))
        let message = try XCTUnwrap(find(album.view, "aiscan.album.validation.message") as? UILabel)
        XCTAssertEqual(message.text, AIScanCameraStrings.localizedMessageKey("해상도가 너무 낮습니다. 더 선명한 사진으로 시도해 주세요."))
        XCTAssertFalse(message.superview!.isHidden)
        XCTAssertNotNil(find(album.view, "aiscan.album.quality.width"), "Keep the requested quality measurements available.")
        let report = try XCTUnwrap(album.qualityReport)
        XCTAssertEqual(AIScanCameraStrings.albumQualityFailureMessage(for: report, isInspecting: false,
            analysisPosition: nil, languageCode: "ko"), "사진이 너무 작아요. 더 큰 원본 사진을 선택해 주세요.")
    }

    func testQualityGuidanceNamesTheActualBodyPartAndClearsAfterAnotherPhotoPasses() throws {
        for (part, expected) in [(AISCPartType.eye, "눈이 더 크게 나온 사진을 선택해 주세요."),
                                 (.teeth, "치아가 더 크게 나온 사진을 선택해 주세요.")] {
            let album = AIScanAlbumSelectionViewController(allowsPositionSelection: false, initialPosition: nil, partType: part)
            album.loadViewIfNeeded()
            let photo = try photo(width: 1600, height: 1600)
            album.onInspect = { _, completion in
                completion(AIScanAlbumQualityReport(metadata: photo.metadata, part: part).measured(CGSize(width: 50, height: 50)))
            }
            album.applySelectedPhoto(photo)
            XCTAssertEqual(AIScanCameraStrings.albumQualityFailureMessage(for: try XCTUnwrap(album.qualityReport),
                isInspecting: false, analysisPosition: nil, languageCode: "ko"), expected)
            album.onInspect = { _, completion in
                completion(AIScanAlbumQualityReport(metadata: photo.metadata, part: part).measured(CGSize(width: 500, height: 500)))
            }
            album.applySelectedPhoto(photo)
            XCTAssertTrue(try XCTUnwrap(find(album.view, "aiscan.album.validation")).isHidden)
            XCTAssertTrue(try XCTUnwrap(find(album.view, "aiscan.album.analyze") as? UIButton).isEnabled)
        }
    }

    func testInspectionServiceFailureDoesNotTellTheUserToReplaceThePhoto() throws {
        let album = AIScanAlbumSelectionViewController(allowsPositionSelection: false, initialPosition: nil, partType: .eye)
        album.loadViewIfNeeded()
        let photo = try photo()
        let error = NSError(domain: AISCErrorDomain, code: 200, userInfo: [AISCDisplayReasonKey: "network_unavailable_internal"])
        album.onInspect = { _, completion in
            completion(AIScanAlbumQualityReport(metadata: photo.metadata, part: .eye).measured(nil, issue: "detect", error: error))
        }
        album.applySelectedPhoto(photo)
        let message = AIScanCameraStrings.albumQualityFailureMessage(for: try XCTUnwrap(album.qualityReport),
            isInspecting: false, analysisPosition: nil, languageCode: "ko")
        XCTAssertEqual(message, "인터넷 연결이 원활하지 않아요. 연결을 확인한 뒤 다시 시도해 주세요.")
        let row = try XCTUnwrap(find(album.view, "aiscan.album.quality.detect_width") as? UILabel)
        XCTAssertFalse(row.text!.contains(AIScanCameraStrings.localizedMessageKey("album.quality.detect")))
        XCTAssertEqual(error.userInfo[AISCDisplayReasonKey] as? String, "network_unavailable_internal")
        XCTAssertEqual(error.code, 200, "Preserve the developer's diagnostic error.")
        let retry = try XCTUnwrap(find(album.view, "aiscan.album.retry-inspection") as? UIButton)
        XCTAssertFalse(retry.isHidden, "A service failure must offer a retry without choosing the photo again.")
        var retriedSamePhoto = false
        album.onInspect = { selected, completion in
            retriedSamePhoto = selected.image === photo.image
            completion(AIScanAlbumQualityReport(metadata: selected.metadata, part: .eye).measured(CGSize(width: 400, height: 400)))
        }
        let action = try XCTUnwrap(retry.actions(forTarget: album, forControlEvent: .touchUpInside)?.first)
        _ = album.perform(NSSelectorFromString(action))
        XCTAssertTrue(retriedSamePhoto)
        XCTAssertTrue(retry.isHidden)
        XCTAssertTrue(try XCTUnwrap(find(album.view, "aiscan.album.analyze") as? UIButton).isEnabled)
    }

    func testAllLanguagesOfferUserGuidanceWithoutCodesForEveryQualityFailure() {
        let original = AIScanAlbumMetadata(width: 1800, height: 1800, bitsPerPixel: 24)
        let reports = [
            AIScanAlbumQualityReport(metadata: AIScanAlbumMetadata(width: 400, height: 400, bitsPerPixel: 24), part: .eye),
            AIScanAlbumQualityReport(metadata: AIScanAlbumMetadata(width: 1800, height: 1800, bitsPerPixel: 8), part: .skin),
            AIScanAlbumQualityReport(metadata: AIScanAlbumMetadata(width: 1800, height: 1800, bitsPerPixel: nil), part: .skin),
            AIScanAlbumQualityReport(metadata: original, part: .eye).measured(nil, issue: "detect"),
            AIScanAlbumQualityReport(metadata: original, part: .teeth).measured(CGSize(width: 50, height: 50)),
            AIScanAlbumQualityReport(metadata: original, part: .eye).measured(nil, issue: "detect", error: NSError(domain: AISCErrorDomain, code: 202)),
        ]
        for language in ["ko", "en", "ja", "it", "sv", "th"] {
            for report in reports {
                let message = AIScanCameraStrings.albumQualityFailureMessage(for: report, isInspecting: false,
                    analysisPosition: nil, languageCode: language)
                XCTAssertNotNil(message)
                for term in ["AISC-", "PRE_", "album.", "photo.color_quality", "bpp", "BBOX"] {
                    XCTAssertFalse(message?.contains(term) == true, "\(language): \(message ?? "")")
                }
            }
        }
        XCTAssertNil(AIScanCameraStrings.albumQualityFailureMessage(for: AIScanAlbumQualityReport(metadata: original, part: .eye),
            isInspecting: true, analysisPosition: nil))
    }

    func testUntranslatedFailureReasonNeverLeaksToTheUser() {
        let error = NSError(domain: AISCErrorDomain, code: AISCErrorCode.frameRejected.rawValue,
            userInfo: [AISCDisplayReasonKey: "PRE_UNRECOGNIZED_INTERNAL_REASON"])
        let message = AIScanCameraStrings.albumDisplayMessage(for: error, partType: .eye, analysisPosition: nil, languageCode: "ko")
        XCTAssertEqual(message, "검사를 진행하지 못했어요. 다시 시도해 주세요.")
    }
}

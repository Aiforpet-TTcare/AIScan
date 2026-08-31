import PDFKit
import UIKit
import XCTest
import AIScanCore
import AIScan
@_spi(AIScanLifecycle) @testable import AIScanCameraUI

@MainActor
private final class DisabledResultViewProbe: UIViewController, AIScanResultViewControlling {
    private(set) var receivedResult: AIScanResult?

    func apply(result: AIScanResult) {
        receivedResult = result
    }
}

@MainActor
final class AIScanPDFReportTests: XCTestCase {
    func testDisplayViewModelSeparatesResultTabsFromTheFullAnalyzedCatalog() {
        let detail = AISCDisplayDetail(
            key: "what_it_is",
            title: "What it is",
            contents: ["Display-safe explanation"]
        )
        let normal = AISCDisplaySymptom(
            code: "hyperemia",
            name: "Redness",
            heatmapURL: nil,
            cropImageURL: nil,
            abnormalLevel: 0,
            resultLabel: "normal",
            details: [detail]
        )
        let abnormal = AISCDisplaySymptom(
            code: "opacity",
            name: "Opacity",
            heatmapURL: nil,
            cropImageURL: nil,
            abnormalLevel: 1,
            resultLabel: "abnormal"
        )
        let result = AISCDisplayResult(
            status: "CAUTION",
            diagnosisID: "diagnosis-1",
            symptoms: [abnormal],
            analyzedSymptoms: [normal, abnormal],
            skinFeatures: nil,
            contractResult: nil,
            requiresRetake: false,
            retakeReasonCode: nil,
            questionnaireAnswers: []
        )

        let viewModel = AIScanDisplayResultViewModel(result: result)

        XCTAssertEqual(viewModel.symptoms.map(\.code), ["opacity"])
        XCTAssertEqual(viewModel.analyzedSymptoms.map(\.code), ["hyperemia", "opacity"])
        XCTAssertEqual(viewModel.analyzedSymptoms.first?.detailRows.first?.text,
                       "<b>What it is</b><br>Display-safe explanation")
    }

    func testQuestionnaireOnlyCautionDoesNotBecomeAnAbnormalImageInThePDF() {
        let normal = AIScanDisplaySymptomViewModel(
            code: "opacity",
            name: "Opacity",
            abnormalLevel: 0,
            resultLabel: "normal"
        )
        let input = AIScanPDFReportInput(
            viewModel: AIScanDisplayResultViewModel(
                status: "CAUTION_Q",
                symptoms: [],
                analyzedSymptoms: [normal]
            ),
            petType: "DOG",
            part: "EYE",
            subpart: "EYER",
            petName: "Bori",
            petDetail: "Bori"
        )

        let props = DiagnosisPdfAdapter.makeProps(from: input)

        XCTAssertFalse(props.diagnoses.isAbnormal)
        XCTAssertTrue(props.diagnoses.symptoms.allSatisfy { !$0.isAbnormal })
    }

    func testHighLevelFacadeCarriesOriginalPDFOptions() throws {
        AIScanManager.configure(
            publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx",
            environment: .production
        )
        defer { AIScanManager.clearConfiguration() }

        let camera = try AIScanManager.makeCameraViewController(
            petType: .dog,
            partType: .eye,
            petName: "Bori",
            petBreedName: "Maltese",
            petBirthday: "2024-01-01",
            petGender: "F",
            enablePdfShare: false
        ) as! AIScanCameraViewController

        XCTAssertEqual(camera.scanContext.petType, .dog)
        XCTAssertEqual(camera.scanContext.partType, .eye)
        XCTAssertEqual(
            AIScanPDFPetDetailFormatter.make(
                petType: "DOG",
                petName: "Bori",
                petBreedName: "Maltese",
                petBirthday: "2024-01-01",
                petGender: "F"
            ),
            "Bori · Maltese · 2024-01-01 · F"
        )
    }

    func testHighLevelFacadeCanReturnResultWithoutPresentingAResultView() throws {
        AIScanManager.configure(
            publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx",
            environment: .production
        )
        defer { AIScanManager.clearConfiguration() }

        let resultView = DisabledResultViewProbe()
        var completionResult: Result<AIScanResult, Error>?
        let camera = try AIScanManager.makeCameraViewController(
            petType: .dog,
            partType: .eye,
            enableResultView: false,
            resultViewController: resultView,
            completion: { completionResult = $0 }
        ) as! AIScanCameraViewController
        camera.loadViewIfNeeded()

        camera.onResult?(AISCDisplayResult(
            status: "NORMAL",
            diagnosisID: "diagnosis-result-view-disabled",
            symptoms: []
        ))

        XCTAssertNil(resultView.receivedResult)
        XCTAssertNil(camera.onResult, "Callback-only mode must close the completed camera flow")
        guard case let .success(result) = completionResult else {
            return XCTFail("Expected the diagnosis callback without result presentation")
        }
        XCTAssertEqual(result.diagnosisID, "diagnosis-result-view-disabled")
    }

    func testReportGeneratesOriginalFourSectionDocument() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let imageData = renderer.pngData { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try imageData.write(to: imageURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let input = AIScanPDFReportInput(
            viewModel: AIScanDisplayResultViewModel(
                status: "WARNING",
                diagnosisID: "diagnosis-1",
                symptoms: [
                    AIScanDisplaySymptomViewModel(
                        code: "opacity",
                        name: "Opacity",
                        heatmapURL: imageURL,
                        cropImageURL: imageURL,
                        abnormalLevel: 1,
                        resultLabel: "abnormal"
                    )
                ],
                analyzedAt: Date(timeIntervalSince1970: 1_780_000_000)
            ),
            petType: "DOG",
            part: "EYE",
            subpart: "EYER",
            petName: "Bori",
            petDetail: "Bori · Maltese"
        )

        let url = try await AIScanPDFReportGenerator.generate(input)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension.lowercased(), "pdf")
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThanOrEqual(document.pageCount, 4)
        let pdfAttachment = XCTAttachment(contentsOfFile: url)
        pdfAttachment.name = "AIScan-screening-report.pdf"
        pdfAttachment.lifetime = .keepAlways
        add(pdfAttachment)
        for index in 0..<min(4, document.pageCount) {
            guard let page = document.page(at: index) else { continue }
            let attachment = XCTAttachment(
                image: page.thumbnail(
                    of: CGSize(width: 595, height: 842),
                    for: .mediaBox
                )
            )
            attachment.name = String(format: "AIScan-screening-page-%02d", index + 1)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
        XCTAssertTrue(text.contains("Bori"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("Opacity"))
    }

    func testReportGenerationRejectsConcurrentOverwrite() async throws {
        let input = AIScanPDFReportInput(
            viewModel: AIScanDisplayResultViewModel(status: "NORMAL"),
            petType: "CAT",
            part: "TOOTH",
            subpart: nil,
            petName: "Nabi",
            petDetail: "Nabi"
        )
        let coordinator = AIScanPDFExportCoordinator()

        async let first = coordinator.generate(input)
        async let second = coordinator.generate(input)
        let results = await [first, second]

        XCTAssertEqual(results.compactMap(\.success).count, 1)
        XCTAssertEqual(results.compactMap(\.failure).count, 1)
        for result in results {
            if case let .success(url) = result {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

private extension Result where Success == URL, Failure == Error {
    var success: URL? {
        guard case let .success(value) = self else { return nil }
        return value
    }

    var failure: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

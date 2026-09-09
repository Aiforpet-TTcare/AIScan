import UIKit
import XCTest
import AIScanCore
@testable import AIScanCameraUI

final class AIScanLifecyclePerformanceTests: XCTestCase {
    @MainActor
    func testRepeatedCameraConstructionDoesNotRetainTheControllerOrOriginalSurfaces() {
        for iteration in 0..<25 {
            weak var releasedCamera: AIScanCameraViewController?
            weak var releasedSurface: CameraViewController?
            weak var releasedOverlay: TTOverlayViewController?

            autoreleasepool {
                let context = AISCScanContext()
                context.petType = iteration.isMultiple(of: 2) ? .dog : .cat
                context.partType = iteration.isMultiple(of: 3) ? .teeth : .eye
                let configuration = AISCConfiguration(
                    publishableKey: "tt_pk_test_lifecycle"
                )
                var camera: AIScanCameraViewController? = AIScanCameraViewController(
                    configuration: configuration,
                    context: context
                )
                camera?.beginsScanningAutomatically = false
                camera?.loadViewIfNeeded()

                releasedCamera = camera
                releasedSurface = camera?.children
                    .compactMap { $0 as? CameraViewController }
                    .first
                releasedOverlay = releasedSurface?.children
                    .compactMap { $0 as? TTOverlayViewController }
                    .first
                camera = nil
            }

            XCTAssertNil(releasedCamera, "camera retained at iteration \(iteration)")
            XCTAssertNil(releasedSurface, "surface retained at iteration \(iteration)")
            XCTAssertNil(releasedOverlay, "overlay retained at iteration \(iteration)")
        }
    }

    @MainActor
    func testProgressPercentageDisplayLinkReleasesAfterAnimationCompletes() async throws {
        weak var releasedProgress: TTProgressViewController?
        weak var releasedCountingLabel: CountingLabel?

        autoreleasepool {
            var progress: TTProgressViewController? = TTProgressViewController.instantiate()
            progress?.loadViewIfNeeded()
            progress?.set(progress: 0.87, animated: true)
            releasedProgress = progress
            releasedCountingLabel = progress?.progressLabel
            progress = nil
        }

        XCTAssertNil(releasedProgress)
        for _ in 0..<20 where releasedCountingLabel != nil {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertNil(
            releasedCountingLabel,
            "The progress CADisplayLink retained its target after the animation deadline."
        )
    }
}

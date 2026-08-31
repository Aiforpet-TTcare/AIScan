import UIKit
import XCTest
@testable import AIScanCameraUI

@MainActor
final class AIScanDisplayAssetBoundaryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AIScanReferenceImageLoader.cache.removeAllObjects()
    }

    func testImageLoaderUsesCoreForSandboxAsset() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let data = renderer.pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = expectation(description: "Core returns a display image")
        AIScanReferenceImageLoader.load(from: url) { image in
            XCTAssertNotNil(image)
            XCTAssertNotNil(AIScanReferenceImageLoader.cache.object(forKey: url as NSURL))
            loaded.fulfill()
        }

        wait(for: [loaded], timeout: 2)
    }

    func testImageLoaderRejectsFileOutsideApplicationSandbox() {
        let rejected = expectation(description: "Core rejects an external file")
        AIScanReferenceImageLoader.load(from: URL(fileURLWithPath: "/etc/hosts")) { image in
            XCTAssertNil(image)
            rejected.fulfill()
        }

        wait(for: [rejected], timeout: 2)
    }
}

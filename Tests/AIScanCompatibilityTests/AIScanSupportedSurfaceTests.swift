import XCTest

final class AIScanSupportedSurfaceTests: XCTestCase {
    func testPublicPackageExposesOnlyAIScanFacadeProduct() throws {
        let manifest = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let facade = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/AIScan/AIScan.swift"),
            encoding: .utf8
        )
        let manager = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/AIScan/AIScanManager.swift"),
            encoding: .utf8
        )

        XCTAssertEqual(manifest.components(separatedBy: ".library(").count - 1, 1)
        XCTAssertTrue(manifest.contains("name: \"AIScan\""))
        XCTAssertFalse(facade.contains("@_exported import AIScanCore"))
        XCTAssertTrue(facade.contains("@_exported import AIScanCameraUI"))
        XCTAssertFalse(manager.contains("public static func configure(configuration:"))
        XCTAssertFalse(manager.contains("public static func configureForValidation"))
        XCTAssertFalse(manager.contains("throws -> AIScanCameraViewController"))
    }

    func testPublicSplitContainsOnlyTheFiveSupportedProductPaths() throws {
        let root = repositoryRoot
        let publicTypes = try String(
            contentsOf: root.appendingPathComponent("Sources/AIScan/AIScanTypes.swift"),
            encoding: .utf8
        )
        let cameraSources = try swiftSources(
            below: root.appendingPathComponent("Sources/AIScanCameraUI")
        )

        XCTAssertFalse(publicTypes.contains("case joint"))
        XCTAssertFalse(cameraSources.contains("case .joint"))
        XCTAssertFalse(cameraSources.contains("import ARKit"))
        XCTAssertFalse(cameraSources.contains("ARSCNView"))
    }

    func testSupportedCameraStoryboardHasNoDeadARSurface() throws {
        let storyboard = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AIScanCameraUI/ReferenceResources/Legacy/TTCamera.storyboard"
            ),
            encoding: .utf8
        )

        XCTAssertFalse(storyboard.contains("<arscnView"))
    }

    func testDistributionMetadataAdvertisesOnlyTheFiveSupportedProductPaths() throws {
        let podspec = try String(
            contentsOf: repositoryRoot.appendingPathComponent("AIScan.podspec"),
            encoding: .utf8
        )

        XCTAssertTrue(podspec.contains("dogs (eyes, teeth, skin) and cats (eyes, teeth)"))
        XCTAssertTrue(podspec.contains("- Dogs: Eyes, Teeth, Skin"))
        XCTAssertTrue(podspec.contains("- Cats: Eyes, Teeth"))
        XCTAssertFalse(podspec.localizedCaseInsensitiveContains("joint"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func swiftSources(below root: URL) throws -> String {
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            )
        )
        var sources: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            sources.append(try String(contentsOf: url, encoding: .utf8))
        }
        return sources.joined(separator: "\n")
    }
}

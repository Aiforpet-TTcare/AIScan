import Foundation
import UIKit
import WebKit
import XCTest
@testable import AIScanCameraUI

private struct GuideTestAnimation: AIScanLottieAsset {
    let jsonString: String?
    var loop = false
    var autoPlay = true
    var size: CGSize { .zero }
}

final class AIScanGuideResourceTests: XCTestCase {
    private let minimalAnimation = """
    {"v":"5.7.0","fr":30,"ip":0,"op":30,"w":10,"h":10,"layers":[]}
    """

    func testAllSevenGuidesResolveFromInstalledResources() throws {
        XCTAssertEqual(AIScanGuideLottie.allCases.count, 7)
        for guide in AIScanGuideLottie.allCases {
            let json = try XCTUnwrap(guide.jsonString, guide.rawValue)
            let data = try XCTUnwrap(json.data(using: .utf8))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertNotNil(object["layers"], guide.rawValue)
            XCTAssertNotNil(object["fr"], guide.rawValue)
        }
    }

    func testResourceLookupFindsMainAppPodBundleWhenFrameworkOnlyContainsStringsBundle() throws {
        try withFixtureRoot { root in
            let frameworkURL = root.appendingPathComponent("Framework.bundle")
            let mainURL = root.appendingPathComponent("Host.bundle")
            let stringsURL = frameworkURL.appendingPathComponent("AIScanCameraUIResources.bundle")
            let referenceURL = mainURL.appendingPathComponent("AIScanReferenceUIResources.bundle")
            try createBundle(at: frameworkURL)
            try createBundle(at: mainURL)
            try createBundle(at: stringsURL)
            try createBundle(at: referenceURL)
            try minimalAnimation.write(to: referenceURL.appendingPathComponent("guideDogEye.json"), atomically: true, encoding: .utf8)
            let framework = try XCTUnwrap(Bundle(url: frameworkURL))
            let main = try XCTUnwrap(Bundle(url: mainURL))
            let bundles = AIScanCameraResourceBundle.resourceBundles(in: [framework, main])

            XCTAssertEqual(bundles.first?.bundleURL.standardizedFileURL.path, referenceURL.standardizedFileURL.path)
            XCTAssertEqual(AIScanGuideLottie.dogEye.jsonString(in: bundles), minimalAnimation)
            XCTAssertEqual(bundles.map(\.bundleURL).count, Set(bundles.map(\.bundleURL)).count)
        }
    }

    func testUnreadableUTF8FallsThroughToNestedGuideResourceInAnotherBundle() throws {
        try withFixtureRoot { root in
            let brokenURL = root.appendingPathComponent("Broken.bundle")
            let validURL = root.appendingPathComponent("Valid.bundle")
            try createBundle(at: brokenURL)
            try createBundle(at: validURL)
            try Data([0xff, 0xfe, 0xff]).write(to: brokenURL.appendingPathComponent("guideDogEye.json"))
            let guideFolder = validURL.appendingPathComponent("GuideMedia")
            try FileManager.default.createDirectory(at: guideFolder, withIntermediateDirectories: true)
            try minimalAnimation.write(to: guideFolder.appendingPathComponent("guideDogEye.json"), atomically: true, encoding: .utf8)
            let broken = try XCTUnwrap(Bundle(url: brokenURL))
            let valid = try XCTUnwrap(Bundle(url: validURL))

            XCTAssertNil(AIScanGuideLottie.dogEye.jsonString(in: [broken]))
            XCTAssertEqual(AIScanGuideLottie.dogEye.jsonString(in: [broken, valid]), minimalAnimation)
            XCTAssertNil(AIScanGuideLottie.catEye.jsonString(in: [broken, valid]))
        }
    }

    @MainActor
    func testMissingGuideCompletesOnceWithoutStartingWebNavigation() {
        var count = 0
        let player = AIScanLottiePlayerController(lottie: GuideTestAnimation(jsonString: nil)) { count += 1 }
        player.loadViewIfNeeded()
        player.viewDidAppear(false)
        player.viewDidAppear(false)
        player.handlePlaybackCommand("failure")
        player.handlePlaybackCommand("finish")

        XCTAssertEqual(count, 1)
        XCTAssertNil(player.webView.url)
        XCTAssertEqual(player.webView.alpha, 0)
    }

    @MainActor
    func testMalformedOrNonPlayableAnimationCompletesInsteadOfWaiting() {
        for json in ["not JSON", "[]", "{}", "{\"layers\":[],\"fr\":0,\"ip\":0,\"op\":1}", "{\"layers\":[],\"fr\":30,\"ip\":1,\"op\":1}"] {
            var count = 0
            let player = AIScanLottiePlayerController(lottie: GuideTestAnimation(jsonString: json)) { count += 1 }
            player.loadAnimation(jsonString: json)
            player.handlePlaybackCommand("finish")
            XCTAssertEqual(count, 1, json)
        }
    }

    @MainActor
    func testSuccessAndRendererFailureSignalsCompleteFiniteGuideExactlyOnce() {
        for commands in [["finish", "finish", "failure"], ["failure", "finish", "failure"]] {
            var count = 0
            let player = AIScanLottiePlayerController(lottie: GuideTestAnimation(jsonString: minimalAnimation)) { count += 1 }
            player.handlePlaybackCommand("unknown")
            XCTAssertEqual(count, 0)
            commands.forEach(player.handlePlaybackCommand)
            XCTAssertEqual(count, 1)
        }
    }

    @MainActor
    func testNavigationAndWebProcessFailuresReleaseFiniteGuideOnce() {
        for failure in 0..<3 {
            var count = 0
            let player = AIScanLottiePlayerController(lottie: GuideTestAnimation(jsonString: minimalAnimation)) { count += 1 }
            player.loadViewIfNeeded()
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotLoadFromNetwork)
            switch failure {
            case 0: player.webView(player.webView, didFail: nil, withError: error)
            case 1: player.webView(player.webView, didFailProvisionalNavigation: nil, withError: error)
            default: player.webViewWebContentProcessDidTerminate(player.webView)
            }
            player.handlePlaybackCommand("finish")
            player.webViewWebContentProcessDidTerminate(player.webView)
            XCTAssertEqual(count, 1)
            XCTAssertEqual(player.webView.alpha, 0)
        }
    }

    @MainActor
    func testMissingLoopingResultArtworkStaysBlankWithoutAdvancingLifecycle() {
        var count = 0
        let player = AIScanLottiePlayerController(lottie: GuideTestAnimation(jsonString: nil, loop: true)) { count += 1 }
        player.loadViewIfNeeded()
        player.viewDidAppear(false)
        player.handlePlaybackCommand("failure")
        player.handlePlaybackCommand("finish")
        XCTAssertEqual(count, 0)
        XCTAssertEqual(player.webView.alpha, 0)
    }

    @MainActor
    func testSilentRendererTimeoutReleasesGuideExactlyOnce() async {
        let completed = expectation(description: "finite guide fallback")
        completed.assertForOverFulfill = true
        let player = AIScanLottiePlayerController(
            lottie: GuideTestAnimation(jsonString: minimalAnimation),
            playbackTimeout: 0
        ) { completed.fulfill() }
        player.loadViewIfNeeded()
        player.viewDidAppear(false)
        await fulfillment(of: [completed], timeout: 1)
        player.handlePlaybackCommand("finish")
        player.handlePlaybackCommand("failure")
        XCTAssertEqual(player.webView.alpha, 0)
    }

    @MainActor
    func testTeardownCancelsFallbackAndIgnoresLateRendererCallbacks() async {
        let completed = expectation(description: "removed guide must not advance capture")
        completed.isInverted = true
        let player = AIScanLottiePlayerController(
            lottie: GuideTestAnimation(jsonString: minimalAnimation),
            playbackTimeout: 0
        ) { completed.fulfill() }
        player.loadViewIfNeeded()
        player.viewDidAppear(false)
        player.willMove(toParent: nil)
        player.handlePlaybackCommand("finish")
        player.handlePlaybackCommand("failure")
        await fulfillment(of: [completed], timeout: 0.1)
    }

    private func withFixtureRoot(_ body: (URL) throws -> Void) throws {
        // Host-side fixtures remain under this checkout, including simulator tests.
        let checkout = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = checkout.appendingPathComponent("tmp/guide-resources-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func createBundle(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": "test.guide.\(UUID().uuidString)", "CFBundlePackageType": "BNDL"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Info.plist"))
    }
}

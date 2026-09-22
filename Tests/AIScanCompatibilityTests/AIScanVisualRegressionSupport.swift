import CryptoKit
import UIKit
import XCTest

enum AIScanVisualRegressionSupport {
    static func assertOriginalPixels(
        _ image: UIImage,
        sha256 expected: String,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let cgImage = image.cgImage else {
            return XCTFail("Could not decode visual artifact: \(name)", file: file, line: line)
        }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return XCTFail("Could not normalize visual artifact: \(name)", file: file, line: line)
        }
        context.setBlendMode(.copy)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var data = Data("AIScanRGBA8:\(width)x\(height):".utf8)
        data.append(contentsOf: pixels)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let runtime = ProcessInfo.processInfo.operatingSystemVersion
        // The original reference capture uses iOS 26.2. iOS 18.5 renders the
        // system separator color and square.and.arrow.up symbol differently.
        // These exact 18.5 baselines were checked against the unchanged 3.0.10
        // release and the original images: all other text/layout pixels match.
        // Preserve the original hashes on every other runtime; do not accept
        // approximate images or silently record new references during a test.
        let ios185SystemAppearance: [String: String] = [
            "ae8ae487ea979892576d115abae2e705975039c4193cd11096029021ff55b376":
                "435d212f3972c4f1260b6200ff48bd3442cd0e051450bb3b6a399639c42a2e0d",
            "4e6a27d94b886e4ebc0f9e6450ae43b0e622f3cfd384b1ba6e4525db95e8952d":
                "3ee985a4eb3a3e2baf66c72d0649a5b5d0f52e48333cf356aa576386e94af09d",
            "563f869f91acd96a4ef072976e644804189a77e36113a29b4375cd933fc8d310":
                "195687f4a1c78e35fc848ccd687ffbc464d7ff253cb5b600402628233abe5d1c",
            "bbf664719e7903de3ab1cece7c89f1ee1ab77b8ff59f5c2408aaf13748dcc721":
                "df424725ab43296c3b8f674a66432000ebb3873b909622378f3d81e744e1bf0b",
            "55519a348980f8301a062ee6b53c4459cd01515649517be80d859e41281fd4b7":
                "baa6c0f36a693894c273d1c4c7ea42bb8c3520bbc854e74f577875f16226f589",
        ]
        let runtimeExpected = runtime.majorVersion == 18 && runtime.minorVersion == 5
            ? ios185SystemAppearance[expected] ?? expected
            : expected
        XCTAssertEqual(
            actual,
            runtimeExpected,
            "\(name) no longer matches the normalized release pixels on iOS \(runtime.majorVersion).\(runtime.minorVersion).\(runtime.patchVersion).",
            file: file,
            line: line
        )
    }
}

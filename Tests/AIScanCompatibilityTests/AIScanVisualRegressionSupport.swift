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
        XCTAssertEqual(
            actual,
            expected,
            "\(name) no longer matches the normalized AIScan 2.2.4 release pixels.",
            file: file,
            line: line
        )
    }
}

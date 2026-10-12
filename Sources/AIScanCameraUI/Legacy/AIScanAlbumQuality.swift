import ImageIO
import UIKit
import AIScanCore

struct AIScanAlbumMetadata: Sendable {
    let width: Int
    let height: Int
    let bitsPerPixel: Int?

    init(width: Int, height: Int, bitsPerPixel: Int?) {
        self.width = width
        self.height = height
        self.bitsPerPixel = bitsPerPixel
    }

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        self.width = width
        self.height = height
        if data.count >= 29, Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10] {
            guard let header = Self.pngHeader(data) else { bitsPerPixel = nil; return }
            let depth = header.depth
            let colorType = header.colorType
            // Indexed pixels store palette indexes, not 24-bit RGB samples.
            let channels: Int?
            switch colorType {
            case 0, 3: channels = 1
            case 2: channels = 3
            case 4: channels = 2
            case 6: channels = 4
            default: channels = nil
            }
            bitsPerPixel = channels.map { depth * $0 }
        } else if let depth = properties[kCGImagePropertyDepth] as? Int,
                  let model = properties[kCGImagePropertyColorModel] as? String {
            let channels: Int?
            if model == (kCGImagePropertyColorModelRGB as String) { channels = 3 }
            else if model == (kCGImagePropertyColorModelCMYK as String) { channels = 4 }
            else if model == (kCGImagePropertyColorModelGray as String) { channels = 1 }
            else { channels = nil }
            let alpha = (properties[kCGImagePropertyHasAlpha] as? Bool) == true ? 1 : 0
            bitsPerPixel = channels.map { depth * ($0 + alpha) }
        } else {
            bitsPerPixel = nil
        }
    }

    private static func pngHeader(_ data: Data) -> (depth: Int, colorType: UInt8)? {
        var offset = 8
        while offset <= data.count - 12 {
            let start = data.startIndex + offset
            let length = (0..<4).reduce(0) { ($0 << 8) | Int(data[start + $1]) }
            guard length <= data.count - offset - 12 else { return nil }
            if Array(data[(start + 4)..<(start + 8)]) == [73, 72, 68, 82] { // IHDR
                guard length == 13 else { return nil }
                let depth = Int(data[start + 16])
                guard [1, 2, 4, 8, 16].contains(depth) else { return nil }
                return (depth, data[start + 17])
            }
            offset += length + 12
        }
        return nil
    }
}

/// Retains metadata from the selected representation, before conversion to BGRA.
struct AIScanAlbumPhoto: @unchecked Sendable {
    let image: UIImage
    let metadata: AIScanAlbumMetadata

    init?(data: Data) {
        guard let metadata = AIScanAlbumMetadata(data: data), let image = UIImage(data: data) else { return nil }
        self.image = image
        self.metadata = metadata
    }

    init(image: UIImage) {
        self.image = image
        metadata = AIScanAlbumMetadata(
            width: image.cgImage?.width ?? 0,
            height: image.cgImage?.height ?? 0,
            bitsPerPixel: nil
        )
    }
}

struct AIScanAlbumQualityReport: Sendable {
    struct Row: Sendable {
        let key: String
        let value: Int?
        let minimum: Int
        let issue: String?
        var passes: Bool { issue == nil && value.map { $0 >= minimum } == true }
    }

    let metadata: AIScanAlbumMetadata
    let part: AISCPartType
    var detectedSize: CGSize?
    var detectionIssue: String?

    init(metadata: AIScanAlbumMetadata, part: AISCPartType) {
        self.metadata = metadata
        self.part = part
    }

    var requiresDetection: Bool { part == .eye || part == .teeth }
    var originalIsValid: Bool { [.eye, .teeth, .skin].contains(part) && originalRows.allSatisfy(\.passes) }
    var isValid: Bool { originalIsValid && (!requiresDetection || detectionRows.allSatisfy(\.passes)) }

    var originalRows: [Row] {
        let minimum = part == .skin ? 1200 : (part == .teeth ? 1400 : 900)
        return [
            row("width", metadata.width, minimum, "resolution"),
            row("height", metadata.height, minimum, "resolution"),
            row("bits", metadata.bitsPerPixel, 24, "bits_reason"),
        ]
    }

    var detectionRows: [Row] {
        guard requiresDetection else { return [] }
        let minimum = part == .teeth ? 400 : 270
        return [
            row("detect_width", pixels(detectedSize?.width), minimum, "distance", override: detectionIssue ?? (detectedSize == nil ? "not_checked" : nil)),
            row("detect_height", pixels(detectedSize?.height), minimum, "distance", override: detectionIssue ?? (detectedSize == nil ? "not_checked" : nil)),
        ]
    }

    func measured(_ size: CGSize?, issue: String? = nil) -> Self {
        var report = self
        report.detectedSize = size
        report.detectionIssue = issue
        return report
    }

    private func pixels(_ value: CGFloat?) -> Int? {
        guard let value, value.isFinite, value >= 0, value < CGFloat(Int.max) else { return nil }
        return Int(floor(value + 0.0001))
    }

    private func row(_ key: String, _ value: Int?, _ minimum: Int, _ failure: String, override: String? = nil) -> Row {
        let issue = override ?? (value == nil ? "unknown" : (value! < minimum ? failure : nil))
        return Row(key: key, value: value, minimum: minimum, issue: issue)
    }
}

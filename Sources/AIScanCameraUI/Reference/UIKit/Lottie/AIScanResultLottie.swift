import CoreGraphics

protocol AIScanLottieAsset: Sendable {
    var jsonString: String? { get }
    var loop: Bool { get }
    var autoPlay: Bool { get }
    var size: CGSize { get }
}

enum AIScanResultLottie: AIScanLottieAsset {
    case normal
    case caution
    case warning

    var jsonString: String? {
        switch self {
        case .normal: resultNormalLottie
        case .caution: resultCautionLottie
        case .warning: resultWarningLottie
        }
    }

    var loop: Bool { true }
    var autoPlay: Bool { true }
    var size: CGSize { CGSize(width: 56, height: 56) }
}

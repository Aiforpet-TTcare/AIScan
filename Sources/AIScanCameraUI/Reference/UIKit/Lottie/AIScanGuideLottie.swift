import CoreGraphics
import Foundation
@preconcurrency import AIScanCore

enum AIScanGuideLottie: String, CaseIterable, AIScanLottieAsset {
    case dogEye = "guideDogEye"
    case dogBody = "guideDogBody"
    case dogEar = "guideDogEar"
    case dogPaw = "guideDogPaw"
    case dogTeeth = "guideDogTeeth"
    case catEye = "guideCatEye"
    case catTeeth = "guideCatTeeth"

    init?(context: AISCScanContext) {
        switch (context.petType, context.partType, context.analysisPosition) {
        case (.cat, .eye, _): self = .catEye
        case (.cat, .teeth, _): self = .catTeeth
        case (.dog, .eye, _): self = .dogEye
        case (.dog, .teeth, _): self = .dogTeeth
        case (.dog, .skin, "ear"): self = .dogEar
        case (.dog, .skin, "foot"): self = .dogPaw
        case (.dog, .skin, _): self = .dogBody
        default: return nil
        }
    }

    var jsonString: String? {
        jsonString(in: AIScanCameraResourceBundle.bundles)
    }

    func jsonString(in bundles: [Bundle]) -> String? {
        for bundle in bundles {
            // Processed resources are flat; manual framework copies may retain folders.
            for directory in [nil, "GuideMedia", "ReferenceResources/GuideMedia"] as [String?] {
                if let url = bundle.url(forResource: rawValue, withExtension: "json", subdirectory: directory),
                   let json = try? String(contentsOf: url, encoding: .utf8) {
                    return json
                }
            }
        }
        return nil
    }

    var loop: Bool { false }
    var autoPlay: Bool { true }
    var size: CGSize { .zero }
}

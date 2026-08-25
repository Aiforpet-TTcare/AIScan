import SwiftUI
import UIKit
import AIScanCore
#if SWIFT_PACKAGE
import AIScanCameraUI
import AIScanReferenceUI
#endif

/// High-level, display-safe entry point for the secure AIScan SDK.
@MainActor
public enum AIScanManager {
    private static var configurationTemplate: AISCConfiguration?

    /// Configures the process-wide default used by `showCamera`.
    ///
    /// Publishable-key validation and authentication remain Core-owned.
    public static func configure(
        publishableKey: String,
        environment: AISCEnvironment = .production
    ) {
        let configuration = AISCConfiguration(publishableKey: publishableKey)
        configuration.environment = environment
        configure(configuration: configuration)
    }

    /// Configures the process-wide default from a Core configuration template.
    public static func configure(configuration: AISCConfiguration) {
        configurationTemplate = copyConfiguration(configuration)
    }

    /// Clears the high-level facade configuration and cancels no active scan.
    public static func clearConfiguration() {
        configurationTemplate = nil
    }

    /// Builds a host-presentable camera without presenting it.
    ///
    /// This is useful for hosts that own a custom presentation container. The
    /// returned controller reports only `AIScanResult` through `completion` or
    /// the optional custom result controller.
    public static func makeCameraViewController(
        petType: PetType,
        partType: PartType,
        analysisSubpart: String? = nil,
        analysisPosition: String? = nil,
        petId: String? = nil,
        userId: String? = nil,
        recordId: String? = nil,
        displayMetadata: [String: String]? = nil,
        resultViewController: (UIViewController & AIScanResultViewControlling)? = nil,
        completion: ((Result<AIScanResult, Error>) -> Void)? = nil
    ) throws -> AIScanCameraViewController {
        guard let configurationTemplate else {
            throw AIScanManagerError.notConfigured
        }

        let context = AISCScanContext()
        context.petType = petType.coreValue
        context.partType = partType.coreValue
        context.displaySubpart = partType.displaySubpart
        context.analysisSubpart = analysisSubpart
        context.analysisPosition = analysisPosition ?? partType.analysisPosition
        context.petIdentifier = petId
        context.userIdentifier = userId
        context.recordIdentifier = recordId
        context.displayMetadata = displayMetadata

        let camera = AIScanCameraViewController(
            configuration: copyConfiguration(configurationTemplate),
            context: context
        )
        let completionGate = AIScanManagerCompletionGate(completion: completion)

        camera.onResult = { [weak camera] displayResult in
            let result = AIScanResult(displayResult: displayResult)
            guard completionGate.claim() else { return }

            if result.contractResult != nil {
                completionGate.complete(.success(result))
                return
            }

            if let resultViewController {
                resultViewController.apply(result: result)
                if camera?.viewIfLoaded?.window != nil {
                    camera?.present(resultViewController, animated: true)
                }
            } else {
                let referenceView = AIScanResultReferenceView(result: displayResult)
                let resultController = UIHostingController(rootView: referenceView)
                if camera?.viewIfLoaded?.window != nil {
                    camera?.present(resultController, animated: true)
                }
            }
            completionGate.complete(.success(result))
        }
        camera.onFailure = { error in
            let nsError = error as NSError
            let isRetryable = nsError.userInfo[AISCRetryableKey] as? Bool == true
            guard !isRetryable else { return }
            guard completionGate.claim() else { return }
            completionGate.complete(.failure(error))
        }
        camera.onClose = {
            guard completionGate.claim() else { return }
            completionGate.complete(.failure(AIScanManagerError.cancelled))
        }

        return camera
    }

    /// Presents the secure camera from a host-owned view controller.
    @discardableResult
    public static func showCamera(
        petType: PetType,
        partType: PartType,
        on presentingViewController: UIViewController,
        analysisSubpart: String? = nil,
        analysisPosition: String? = nil,
        petId: String? = nil,
        userId: String? = nil,
        recordId: String? = nil,
        displayMetadata: [String: String]? = nil,
        resultViewController: (UIViewController & AIScanResultViewControlling)? = nil,
        completion: ((Result<AIScanResult, Error>) -> Void)? = nil
    ) throws -> UIViewController {
        let camera = try makeCameraViewController(
            petType: petType,
            partType: partType,
            analysisSubpart: analysisSubpart,
            analysisPosition: analysisPosition,
            petId: petId,
            userId: userId,
            recordId: recordId,
            displayMetadata: displayMetadata,
            resultViewController: resultViewController,
            completion: completion
        )
        presentingViewController.present(camera, animated: true)
        return camera
    }

    private static func copyConfiguration(_ source: AISCConfiguration) -> AISCConfiguration {
        let copy = AISCConfiguration(publishableKey: source.publishableKey)
        copy.environment = source.environment
        copy.bundleIdentifierOverride = source.bundleIdentifierOverride
        copy.appVersionOverride = source.appVersionOverride
        copy.teamIdentifierOverride = source.teamIdentifierOverride
        copy.resourceDirectoryURL = source.resourceDirectoryURL
        copy.requestTimeout = source.requestTimeout
        copy.diagnosisTimeout = source.diagnosisTimeout
        copy.diagnosisPollInterval = source.diagnosisPollInterval
        copy.callbackQueue = source.callbackQueue
        return copy
    }
}

public enum AIScanManagerError: LocalizedError, Equatable {
    case notConfigured
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Call AIScanManager.configure before showing the camera."
        case .cancelled:
            "The scan was cancelled."
        }
    }
}

@MainActor
private final class AIScanManagerCompletionGate {
    private var completion: ((Result<AIScanResult, Error>) -> Void)?
    private var isFinished = false

    init(completion: ((Result<AIScanResult, Error>) -> Void)?) {
        self.completion = completion
    }

    func claim() -> Bool {
        guard !isFinished else { return false }
        isFinished = true
        return true
    }

    func complete(_ result: Result<AIScanResult, Error>) {
        let completion = completion
        self.completion = nil
        completion?(result)
    }
}

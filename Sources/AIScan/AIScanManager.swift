import SwiftUI
import UIKit
import AIScanCore
#if SWIFT_PACKAGE
@_spi(AIScanLifecycle) import AIScanCameraUI
import AIScanReferenceUI
#endif

/// High-level, display-safe entry point for the secure AIScan SDK.
@MainActor
public enum AIScanManager {
    private static var configurationTemplate: AISCConfiguration?
    private static let pdfExportCoordinator = AIScanPDFExportCoordinator()

    /// Called on the main actor after a report has been generated successfully.
    public static var onPDFExported: ((URL) -> Void)?
    public private(set) static var lastExportedPDFURL: URL?

    /// Configures the process-wide default used by `showCamera`.
    ///
    /// Publishable-key validation and authentication remain Core-owned.
    public static func configure(
        publishableKey: String,
        environment: AIScanEnvironment = .production
    ) {
        let configuration = AISCConfiguration(publishableKey: publishableKey)
        configuration.environment = environment.coreValue
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
        petName: String? = nil,
        petBreedName: String? = nil,
        petBirthday: String? = nil,
        petGender: String? = nil,
        userId: String? = nil,
        recordId: String? = nil,
        displayMetadata: [String: String]? = nil,
        enablesQuestionnaire: Bool = false,
        allowsAlbum: Bool = false,
        enableResultView: Bool = false,
        enablePdfShare: Bool = true,
        resultViewController: (UIViewController & AIScanResultViewControlling)? = nil,
        completion: ((Result<AIScanResult, Error>) -> Void)? = nil
    ) throws -> UIViewController {
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
        context.questionnaireEnabled = enablesQuestionnaire

        let camera = AIScanCameraViewController(
            configuration: copyConfiguration(configurationTemplate),
            context: context,
            allowsAlbum: allowsAlbum
        )
        let completionGate = AIScanManagerCompletionGate(completion: completion)

        camera.onResult = { [weak camera] displayResult in
            let displayViewModel = AIScanDisplayResultViewModel(result: displayResult)
            let result = AIScanResult(
                legacyDisplayResult: displayResult,
                petType: petType,
                partType: partType,
                subPart: Self.legacyResultSubPart(context: context),
                petId: petId,
                userId: userId,
                title: displayViewModel.legacyCallbackTitle,
                questionnaireDescription: displayViewModel.legacyQuestionnaireDescription
            )
            guard completionGate.claim() else { return }

            guard enableResultView else {
                guard let camera else {
                    completionGate.complete(.success(result))
                    return
                }
                camera.dismissCompletedScan {
                    completionGate.complete(.success(result))
                }
                return
            }

            if let resultViewController {
                resultViewController.apply(result: result)
                resultViewController.modalPresentationStyle = .fullScreen
                if camera?.viewIfLoaded?.window != nil {
                    camera?.present(resultViewController, animated: true) {
                        camera?.resultDidBecomeVisible()
                    }
                }
            } else {
                let reportInput = AIScanPDFReportInput(
                    viewModel: displayViewModel,
                    petType: petType.rawValue.uppercased(),
                    part: partType.key,
                    subpart: partType.detailKey,
                    petName: petName ?? "",
                    petDetail: AIScanPDFPetDetailFormatter.make(
                        petType: petType.rawValue,
                        petName: petName,
                        petBreedName: petBreedName,
                        petBirthday: petBirthday,
                        petGender: petGender
                    )
                )
                let exportAction: (() -> Void)? = enablePdfShare ? { [weak camera] in
                    guard let camera else { return }
                    Task { @MainActor in
                        switch await pdfExportCoordinator.generate(reportInput) {
                        case let .success(url):
                            lastExportedPDFURL = url
                            onPDFExported?(url)
                            if AIScanPDFSharePresenter.present(fileURL: url, from: camera) {
                                camera.resultDidShare()
                            }
                        case let .failure(error):
                            if error as? AIScanPDFReportError != .exportInProgress {
                                AIScanPDFSharePresenter.showFailure(from: camera)
                            }
                        }
                    }
                } : nil
                let referenceView = AIScanResultReferenceView(
                    viewModel: displayViewModel,
                    onClose: { [weak camera] in
                        camera?.dismissCompletedScan()
                    },
                    onExportReport: exportAction
                )
                let resultController = UIHostingController(rootView: referenceView)
                resultController.modalPresentationStyle = .fullScreen
                if camera?.viewIfLoaded?.window != nil {
                    camera?.present(resultController, animated: true) {
                        camera?.resultDidBecomeVisible()
                    }
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

    private static func legacyResultSubPart(context: AISCScanContext) -> String? {
        let value = context.analysisSubpart
            ?? context.displaySubpart
            ?? context.analysisPosition
        guard let value, !value.isEmpty else { return nil }
        return value.uppercased()
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
        petName: String? = nil,
        petBreedName: String? = nil,
        petBirthday: String? = nil,
        petGender: String? = nil,
        userId: String? = nil,
        recordId: String? = nil,
        displayMetadata: [String: String]? = nil,
        enablesQuestionnaire: Bool = false,
        allowsAlbum: Bool = false,
        enableResultView: Bool = false,
        enablePdfShare: Bool = true,
        resultViewController: (UIViewController & AIScanResultViewControlling)? = nil,
        completion: ((Result<AIScanResult, Error>) -> Void)? = nil
    ) throws -> UIViewController {
        let camera = try makeCameraViewController(
            petType: petType,
            partType: partType,
            analysisSubpart: analysisSubpart,
            analysisPosition: analysisPosition,
            petId: petId,
            petName: petName,
            petBreedName: petBreedName,
            petBirthday: petBirthday,
            petGender: petGender,
            userId: userId,
            recordId: recordId,
            displayMetadata: displayMetadata,
            enablesQuestionnaire: enablesQuestionnaire,
            allowsAlbum: allowsAlbum,
            enableResultView: enableResultView,
            enablePdfShare: enablePdfShare,
            resultViewController: resultViewController,
            completion: completion
        )
        presentingViewController.present(camera, animated: true)
        return camera
    }

    private static func copyConfiguration(_ source: AISCConfiguration) -> AISCConfiguration {
        let copy = AISCConfiguration(publishableKey: source.publishableKey)
        copy.environment = source.environment
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

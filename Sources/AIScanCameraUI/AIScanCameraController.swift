@preconcurrency import AVFoundation
import UIKit
@preconcurrency import AIScanCore

struct AIScanPreparationProgressSnapshot: Equatable {
    let normalizedProgress: Double
    let bytesWritten: Int64
    let totalBytes: Int64
    let bytesPerSecond: Double
}

@MainActor
public protocol AIScanCameraControllerDelegate: AnyObject {
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didCapturePreview image: UIImage)
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdateDiagnosisProgress progress: Double)
    func aiscanCameraController(_ controller: AIScanCameraController, didRequest questionnaire: AISCQuestionnaire)
    func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult)
    func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error)
}

public extension AIScanCameraControllerDelegate {
    func aiscanCameraController(_ controller: AIScanCameraController, didCapturePreview image: UIImage) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdateDiagnosisProgress progress: Double) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didRequest questionnaire: AISCQuestionnaire) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult) {}
}

public final class AIScanCameraController: NSObject, @unchecked Sendable {
    /// The UI may render this session, but the private Core owns and configures it.
    public var captureSession: AVCaptureSession { cameraEngine.captureSession }
    @MainActor
    public weak var delegate: AIScanCameraControllerDelegate?
    public var automaticallyCapturesReadyFrames: Bool = false {
        didSet {
            cameraEngine.automaticallyCapturesReadyFrames = automaticallyCapturesReadyFrames
        }
    }

    private let cameraEngine: AISCCameraEngineControlling
    var analysisMode: AISCAnalysisMode { cameraEngine.analysisMode }
    private static let previewRenderer = CIContext(options: [
        .cacheIntermediates: false,
    ])

    public convenience init(publishableKey: String) {
        self.init(configuration: AISCConfiguration(publishableKey: publishableKey))
    }

    public init(configuration: AISCConfiguration) {
        self.cameraEngine = AISCCameraEngine(configuration: configuration)
        super.init()
        self.cameraEngine.delegate = self
    }

    init(cameraEngine: AISCCameraEngineControlling) {
        self.cameraEngine = cameraEngine
        super.init()
        self.cameraEngine.delegate = self
    }

    public func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            cameraEngine.requestCameraAccess { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func prepare(context: AISCScanContext, completion: @escaping (Error?) -> Void) {
        let completion = AIScanUncheckedSendable(completion)
        cameraEngine.prepare(with: context) { error in
            completion.value(error)
        }
    }

    public func prepare(
        context: AISCScanContext,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        let progress = AIScanUncheckedSendable(progress)
        let completion = AIScanUncheckedSendable(completion)
        cameraEngine.prepare(with: context, progress: { value in
            progress.value(value)
        }) { error in
            completion.value(error)
        }
    }

    func prepare(
        context: AISCScanContext,
        detailedProgress: @escaping (AIScanPreparationProgressSnapshot) -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        let detailedProgress = AIScanUncheckedSendable(detailedProgress)
        let completion = AIScanUncheckedSendable(completion)
        cameraEngine.prepare(with: context, detailedProgress: { normalized, written, total, speed in
            detailedProgress.value(
                AIScanPreparationProgressSnapshot(
                    normalizedProgress: normalized,
                    bytesWritten: written,
                    totalBytes: total,
                    bytesPerSecond: speed
                )
            )
        }) { error in
            completion.value(error)
        }
    }

    public func configure(position: AVCaptureDevice.Position = .back) throws {
        do {
            try cameraEngine.configure(position: position, disable4K: false)
        } catch {
            throw mappedCameraError(error)
        }
    }

    public func makePreviewLayer(videoGravity: AVLayerVideoGravity = .resizeAspectFill) -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = videoGravity
        return layer
    }

    @MainActor
    public func attachPreview(to view: UIView, videoGravity: AVLayerVideoGravity = .resizeAspectFill) {
        let layer = makePreviewLayer(videoGravity: videoGravity)
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
    }

    public func startRunning() {
        cameraEngine.startRunning()
    }

    public func stopRunning() {
        cameraEngine.stopRunning()
    }

    public func setTorchEnabled(_ enabled: Bool) throws {
        do {
            try cameraEngine.setTorchEnabled(enabled)
        } catch {
            throw mappedCameraError(error)
        }
    }

    public func setZoomFactor(_ factor: CGFloat) throws {
        do {
            try cameraEngine.setZoomFactor(factor)
        } catch {
            throw mappedCameraError(error)
        }
    }

    public func scaleZoom(by scale: CGFloat) throws {
        do {
            try cameraEngine.scaleZoom(by: scale)
        } catch {
            throw mappedCameraError(error)
        }
    }

    public func captureNextFrame() {
        cameraEngine.requestCapture()
    }

    func beginCaptureAttempt() {
        cameraEngine.beginCaptureAttempt?()
    }

    func captureAttemptTimedOut() {
        cameraEngine.captureAttemptTimedOut?()
    }

    func albumDidOpen() {
        cameraEngine.albumDidOpen?()
    }

    func albumDidCancel() {
        cameraEngine.albumDidCancel?()
    }

    func resultDidBecomeVisible() {
        cameraEngine.resultDidBecomeVisible?()
    }

    func resultDidShare() {
        cameraEngine.resultDidShare?()
    }

    /// Converts the selected UIImage to the private Core image input.
    func diagnosePhoto(_ image: UIImage) throws {
        guard image.size.width >= 100, image.size.height >= 100 else {
            throw NSError(
                domain: AISCErrorDomain,
                code: AISCErrorCode.invalidInput.rawValue,
                userInfo: [
                    AISCDisplayReasonKey: "해상도가 너무 낮습니다. 더 선명한 사진으로 시도해 주세요.",
                    AISCRetryableKey: true,
                ]
            )
        }
        let sourceImage: CIImage
        if let cgImage = image.cgImage {
            sourceImage = CIImage(cgImage: cgImage)
        } else if let ciImage = image.ciImage {
            sourceImage = ciImage
        } else {
            throw AIScanCameraControllerError.cannotCreateImageInput
        }
        let exifOrientation: Int32
        switch image.imageOrientation {
        case .up: exifOrientation = 1
        case .upMirrored: exifOrientation = 2
        case .down: exifOrientation = 3
        case .downMirrored: exifOrientation = 4
        case .leftMirrored: exifOrientation = 5
        case .right: exifOrientation = 6
        case .rightMirrored: exifOrientation = 7
        case .left: exifOrientation = 8
        @unknown default: exifOrientation = 1
        }
        let coreImage = sourceImage.oriented(forExifOrientation: exifOrientation)
        cameraEngine.diagnosePhoto(coreImage)
    }

    public func resetCaptureAttempt() {
        cameraEngine.resetCaptureAttempt()
    }

    public func reset() {
        cameraEngine.reset()
    }

    public func cancel() {
        cameraEngine.cancel()
    }

    /// Submits display-safe answers to the private Core. Core alone owns
    /// serialization, transport, retry, persistence, and diagnostic events.
    public func submitQuestionnaireAnswers(_ answers: [AISCQuestionnaireAnswer]) {
        cameraEngine.submitQuestionnaireAnswers(answers)
    }

    private func notifyUpdate(_ evaluation: AISCFrameEvaluation) {
        let evaluation = AIScanUncheckedSendable(evaluation)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didUpdate: evaluation.value)
        }
    }

    private func notifyCapture(_ evaluation: AISCFrameEvaluation) {
        let evaluation = AIScanUncheckedSendable(evaluation)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didCapture: evaluation.value)
        }
    }

    private func notifyCapturePreview(_ previewImage: CIImage) {
        let extent = previewImage.extent.integral
        guard !extent.isInfinite,
              !extent.isNull,
              !extent.isEmpty,
              let cgImage = Self.previewRenderer.createCGImage(
                  previewImage,
                  from: extent
              ) else {
            return
        }
        let renderedImage = AIScanUncheckedSendable(
            UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(
                self,
                didCapturePreview: renderedImage.value
            )
        }
    }

    private func notifyResult(_ result: AISCDisplayResult) {
        let result = AIScanUncheckedSendable(result)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didProduce: result.value)
        }
    }

    private func notifyDiagnosisProgress(_ progress: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didUpdateDiagnosisProgress: progress)
        }
    }

    private func notifyQuestionnaire(_ questionnaire: AISCQuestionnaire) {
        let questionnaire = AIScanUncheckedSendable(questionnaire)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(
                self,
                didRequest: questionnaire.value
            )
        }
    }

    private func notifyFailure(_ error: Error) {
        let error = AIScanUncheckedSendable(error)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didFail: error.value)
        }
    }

    private func mappedCameraError(_ error: Error) -> Error {
        let reason = (error as NSError).userInfo[AISCDisplayReasonKey] as? String
        switch reason {
        case "camera_unavailable":
            return AIScanCameraControllerError.cameraUnavailable
        case "cannot_add_camera_input":
            return AIScanCameraControllerError.cannotAddInput
        case "cannot_add_camera_output":
            return AIScanCameraControllerError.cannotAddOutput
        case "unsupported_session_preset":
            return AIScanCameraControllerError.unsupportedSessionPreset
        case "invalid_zoom", "invalid_zoom_scale":
            return AIScanCameraControllerError.notConfigured
        case "torch_unavailable":
            return AIScanCameraControllerError.torchUnavailable
        default:
            return error
        }
    }

}

extension AIScanCameraController: AISCCameraEngineDelegate {
    public func cameraEngineDidUpdateFrameState(_ evaluation: AISCFrameEvaluation) {
        notifyUpdate(evaluation)
    }

    public func cameraEngineDidAcceptCaptureState(_ evaluation: AISCFrameEvaluation) {
        notifyCapture(evaluation)
    }

    public func cameraEngineDidAcceptPreviewImage(_ previewImage: CIImage) {
        notifyCapturePreview(previewImage)
    }

    public func cameraEngineDidUpdateProgress(_ normalizedProgress: Double) {
        notifyDiagnosisProgress(normalizedProgress)
    }

    public func cameraEngineDidRequest(_ questionnaire: AISCQuestionnaire) {
        notifyQuestionnaire(questionnaire)
    }

    public func cameraEngineDidComplete(_ result: AISCDisplayResult) {
        notifyResult(result)
    }

    public func cameraEngineDidFail(_ error: Error) {
        notifyFailure(error)
    }
}

public enum AIScanCameraControllerError: Error {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case unsupportedSessionPreset
    case notConfigured
    case torchUnavailable
    case emptyFrameEvaluation
    case emptyCaptureEvaluation
    case cannotCreateImageInput
    case emptyDiagnosisResult
}

private struct AIScanUncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

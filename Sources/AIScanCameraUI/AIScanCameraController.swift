@preconcurrency import AVFoundation
import CoreMedia
import UIKit
@preconcurrency import AIScanCore

@MainActor
public protocol AIScanCameraControllerDelegate: AnyObject {
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult)
    func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error)
}

public extension AIScanCameraControllerDelegate {
    func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult) {}
}

public final class AIScanCameraController: NSObject, @unchecked Sendable {
    public let captureSession: AVCaptureSession
    public let coreSession: AISCSession
    @MainActor
    public weak var delegate: AIScanCameraControllerDelegate?
    public var automaticallyCapturesReadyFrames: Bool = false

    private let captureQueue = DispatchQueue(label: "com.aiforpet.AIScan.camera.capture")
    private let sessionQueue = DispatchQueue(label: "com.aiforpet.AIScan.camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private weak var activeDevice: AVCaptureDevice?
    private var isEvaluatingFrame = false
    private var isCaptureInProgress = false
    private var pendingManualCapture = false

    public convenience init(publishableKey: String) {
        self.init(configuration: AISCConfiguration(publishableKey: publishableKey))
    }

    public init(configuration: AISCConfiguration) {
        self.captureSession = AVCaptureSession()
        self.coreSession = AISCSession(configuration: configuration)
        super.init()
    }

    public static func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func prepare(context: AISCScanContext, completion: @escaping (Error?) -> Void) {
        let completion = AIScanUncheckedSendable(completion)
        coreSession.prepare(with: context) { error in
            completion.value(error)
        }
    }

    public func configure(position: AVCaptureDevice.Position = .back) throws {
        guard let device = coreSession.cameraDevice(for: position) else {
            throw AIScanCameraControllerError.cameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        guard captureSession.canAddInput(input) else {
            throw AIScanCameraControllerError.cannotAddInput
        }
        captureSession.addInput(input)
        guard coreSession.applyCameraSessionPolicy(
            to: captureSession,
            device: device,
            disable4K: false
        ) else {
            throw AIScanCameraControllerError.unsupportedSessionPreset
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw AIScanCameraControllerError.cannotAddOutput
        }
        captureSession.addOutput(videoOutput)

        activeDevice = device
        coreSession.applyCameraDevicePolicy(to: device, enabled: true)
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
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    public func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    public func setTorchEnabled(_ enabled: Bool) throws {
        guard let device = activeDevice, device.hasTorch else {
            throw AIScanCameraControllerError.torchUnavailable
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.torchMode = enabled ? .on : .off
    }

    public func setZoomFactor(_ factor: CGFloat) throws {
        guard let device = activeDevice else {
            throw AIScanCameraControllerError.notConfigured
        }
        let clamped = coreSession.cameraZoomFactor(for: factor, device: device)
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.videoZoomFactor = clamped
    }

    public func captureNextFrame() {
        captureQueue.async { [weak self] in
            self?.pendingManualCapture = true
        }
    }

    /// Diagnoses a host-selected still image through the same Core-owned
    /// display-safe result boundary used by live capture.
    public func diagnoseImage(at imageURL: URL) {
        let input = AISCImageInput(imageURL: imageURL)
        coreSession.diagnoseImage(input) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.notifyFailure(error)
                return
            }
            guard let result else {
                self.notifyFailure(AIScanCameraControllerError.emptyDiagnosisResult)
                return
            }
            self.notifyResult(result)
        }
    }

    public func reset() {
        coreSession.reset()
        captureQueue.async { [weak self] in
            self?.pendingManualCapture = false
            self?.isEvaluatingFrame = false
            self?.isCaptureInProgress = false
        }
    }

    public func cancel() {
        coreSession.cancel()
        stopRunning()
    }

    private func evaluate(sampleBuffer: CMSampleBuffer) {
        guard !isEvaluatingFrame else { return }
        guard let input = coreSession.frameInput(for: sampleBuffer, device: activeDevice) else { return }
        isEvaluatingFrame = true

        let sendableInput = AIScanUncheckedSendable(input)
        coreSession.evaluateFrame(sendableInput.value) { [weak self] evaluation, error in
            guard let self else { return }
            self.captureQueue.async {
                self.isEvaluatingFrame = false
            }

            if let error {
                self.notifyFailure(error)
                return
            }
            guard let evaluation else {
                self.notifyFailure(AIScanCameraControllerError.emptyFrameEvaluation)
                return
            }
            self.notifyUpdate(evaluation)

            if self.automaticallyCapturesReadyFrames,
               evaluation.captureAllowed {
                self.requestCapture(input: sendableInput.value)
            }
        }
    }

    private func requestCapture(input: AISCFrameInput) {
        captureQueue.async { [weak self] in
            guard let self, !self.isCaptureInProgress else { return }
            self.isCaptureInProgress = true
            self.capture(input: input)
        }
    }

    private func capture(input: AISCFrameInput) {
        coreSession.captureFrame(input) { [weak self] evaluation, error in
            guard let self else { return }
            if let error {
                self.finishCaptureForRetry()
                self.notifyFailure(error)
                return
            }
            guard let evaluation else {
                self.finishCaptureForRetry()
                self.notifyFailure(AIScanCameraControllerError.emptyCaptureEvaluation)
                return
            }
            guard evaluation.captureAllowed else {
                self.finishCaptureForRetry()
                self.notifyUpdate(evaluation)
                return
            }
            self.notifyCapture(evaluation)
            self.diagnose(input: input)
        }
    }

    private func diagnose(input: AISCFrameInput) {
        guard let imageInput = AISCImageInput(pixelBuffer: input.pixelBuffer) else {
            finishCaptureForRetry()
            notifyFailure(AIScanCameraControllerError.cannotCreateImageInput)
            return
        }

        coreSession.diagnoseImage(imageInput) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.finishCaptureForRetry()
                self.notifyFailure(error)
                return
            }
            guard let result else {
                self.finishCaptureForRetry()
                self.notifyFailure(AIScanCameraControllerError.emptyDiagnosisResult)
                return
            }
            self.notifyResult(result)
        }
    }

    private func finishCaptureForRetry() {
        captureQueue.async { [weak self] in
            self?.isCaptureInProgress = false
        }
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

    private func notifyResult(_ result: AISCDisplayResult) {
        let result = AIScanUncheckedSendable(result)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didProduce: result.value)
        }
    }

    private func notifyFailure(_ error: Error) {
        let error = AIScanUncheckedSendable(error)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didFail: error.value)
        }
    }
}

extension AIScanCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if pendingManualCapture {
            pendingManualCapture = false
            guard let input = coreSession.frameInput(for: sampleBuffer, device: activeDevice) else { return }
            requestCapture(input: input)
            return
        }

        evaluate(sampleBuffer: sampleBuffer)
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

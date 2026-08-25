@preconcurrency import AVFoundation
import CoreMedia
import UIKit
@preconcurrency import AIScanCore

@MainActor
public protocol AIScanCameraControllerDelegate: AnyObject {
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdateDiagnosisProgress progress: Double)
    func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult)
    func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error)
}

public extension AIScanCameraControllerDelegate {
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdateDiagnosisProgress progress: Double) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult) {}
}

public final class AIScanCameraController: NSObject, @unchecked Sendable {
    public let captureSession: AVCaptureSession
    @MainActor
    public weak var delegate: AIScanCameraControllerDelegate?
    public var automaticallyCapturesReadyFrames: Bool = false {
        didSet {
            cameraEngine.automaticallyCapturesReadyFrames = automaticallyCapturesReadyFrames
        }
    }

    private let captureQueue = DispatchQueue(label: "com.aiforpet.AIScan.camera.capture")
    private let sessionQueue = DispatchQueue(label: "com.aiforpet.AIScan.camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let cameraEngine: AISCCameraEngineControlling
    private weak var activeDevice: AVCaptureDevice?

    public convenience init(publishableKey: String) {
        self.init(configuration: AISCConfiguration(publishableKey: publishableKey))
    }

    public init(configuration: AISCConfiguration) {
        self.captureSession = AVCaptureSession()
        self.cameraEngine = AISCCameraEngine(configuration: configuration)
        super.init()
        self.cameraEngine.delegate = self
    }

    init(
        cameraEngine: AISCCameraEngineControlling,
        captureSession: AVCaptureSession = AVCaptureSession()
    ) {
        self.captureSession = captureSession
        self.cameraEngine = cameraEngine
        super.init()
        self.cameraEngine.delegate = self
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
        cameraEngine.prepare(with: context) { error in
            completion.value(error)
        }
    }

    public func configure(position: AVCaptureDevice.Position = .back) throws {
        guard let device = cameraEngine.cameraDevice(for: position) else {
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
        guard cameraEngine.applyCameraSessionPolicy(
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
        cameraEngine.applyCameraDevicePolicy(to: device, enabled: true)
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
        let clamped = cameraEngine.cameraZoomFactor(for: factor, device: device)
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.videoZoomFactor = clamped
    }

    public func captureNextFrame() {
        cameraEngine.requestCapture()
    }

    public func reset() {
        cameraEngine.reset()
    }

    public func cancel() {
        cameraEngine.cancel()
        stopRunning()
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

    private func notifyDiagnosisProgress(_ progress: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didUpdateDiagnosisProgress: progress)
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
        cameraEngine.consume(sampleBuffer, device: activeDevice)
    }
}

extension AIScanCameraController: AISCCameraEngineDelegate {
    public func cameraEngineDidUpdateFrameState(_ evaluation: AISCFrameEvaluation) {
        notifyUpdate(evaluation)
    }

    public func cameraEngineDidAcceptCaptureState(_ evaluation: AISCFrameEvaluation) {
        notifyCapture(evaluation)
    }

    public func cameraEngineDidUpdateProgress(_ normalizedProgress: Double) {
        notifyDiagnosisProgress(normalizedProgress)
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

import AVFoundation
import CoreMedia
import UIKit
import AIScanCore

public protocol AIScanCameraControllerDelegate: AnyObject {
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation)
    func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error)
}

public final class AIScanCameraController: NSObject {
    public let captureSession: AVCaptureSession
    public let coreSession: AISCSession
    public weak var delegate: AIScanCameraControllerDelegate?
    public var appliesCoreDevicePolicy: Bool = true
    public var automaticallyCapturesReadyFrames: Bool = false

    private let captureQueue = DispatchQueue(label: "com.aiforpet.AIScan.camera.capture")
    private let sessionQueue = DispatchQueue(label: "com.aiforpet.AIScan.camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private weak var activeDevice: AVCaptureDevice?
    private var isEvaluatingFrame = false
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
        coreSession.prepare(with: context) { error in
            completion(error)
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
        if appliesCoreDevicePolicy {
            coreSession.applyCameraDevicePolicy(to: device, enabled: true)
        }
    }

    public func makePreviewLayer(videoGravity: AVLayerVideoGravity = .resizeAspectFill) -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = videoGravity
        return layer
    }

    public func attachPreview(to view: UIView, videoGravity: AVLayerVideoGravity = .resizeAspectFill) {
        let layer = makePreviewLayer(videoGravity: videoGravity)
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
    }

    public func startRunning() {
        sessionQueue.async { [captureSession] in
            guard !captureSession.isRunning else { return }
            captureSession.startRunning()
        }
    }

    public func stopRunning() {
        sessionQueue.async { [captureSession] in
            guard captureSession.isRunning else { return }
            captureSession.stopRunning()
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

    public func reset() {
        coreSession.reset()
        captureQueue.async { [weak self] in
            self?.pendingManualCapture = false
            self?.isEvaluatingFrame = false
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

        coreSession.evaluateFrame(input) { [weak self] evaluation, error in
            guard let self else { return }
            self.captureQueue.async {
                self.isEvaluatingFrame = false
            }

            if let error {
                self.notifyFailure(error)
                return
            }
            guard let evaluation else { return }
            self.notifyUpdate(evaluation)

            if self.automaticallyCapturesReadyFrames,
               evaluation.captureAllowed {
                self.capture(input: input)
            }
        }
    }

    private func capture(input: AISCFrameInput) {
        coreSession.captureFrame(input) { [weak self] evaluation, error in
            guard let self else { return }
            if let error {
                self.notifyFailure(error)
                return
            }
            guard let evaluation else { return }
            self.notifyCapture(evaluation)
        }
    }

    private func notifyUpdate(_ evaluation: AISCFrameEvaluation) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didUpdate: evaluation)
        }
    }

    private func notifyCapture(_ evaluation: AISCFrameEvaluation) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didCapture: evaluation)
        }
    }

    private func notifyFailure(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aiscanCameraController(self, didFail: error)
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
            capture(input: input)
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
}

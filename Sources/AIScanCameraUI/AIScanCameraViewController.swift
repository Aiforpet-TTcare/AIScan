@preconcurrency import AVFoundation
import UIKit
@preconcurrency import AIScanCore

/// Minimal host-presentable camera controller for the high-level AIScan facade.
///
/// Capture approval and diagnosis policy remain inside `AIScanCore`. This
/// controller owns only AVFoundation/UI execution and display-safe callbacks.
@MainActor
public final class AIScanCameraViewController: UIViewController {
    public let cameraController: AIScanCameraController
    public let scanContext: AISCScanContext

    public var onResult: ((AISCDisplayResult) -> Void)?
    public var onFailure: ((Error) -> Void)?
    public var onClose: (() -> Void)?

    let chromeView = AIScanCameraChromeView()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didBeginScanning = false
    private var isClosed = false
    var beginsScanningAutomatically = true

    public init(configuration: AISCConfiguration, context: AISCScanContext) {
        self.cameraController = AIScanCameraController(configuration: configuration)
        self.scanContext = context
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        overrideUserInterfaceStyle = .dark
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black
        cameraController.delegate = self
        cameraController.automaticallyCapturesReadyFrames = true
        configureLayout()
        if beginsScanningAutomatically {
            beginScanningIfNeeded()
        } else {
            previewLayer?.isHidden = true
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraController.stopRunning()
    }

    deinit {
        cameraController.cancel()
    }

    private func configureLayout() {
        let previewLayer = cameraController.makePreviewLayer()
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        chromeView.translatesAutoresizingMaskIntoConstraints = false
        chromeView.onCapture = { [weak self] in
            self?.cameraController.captureNextFrame()
        }
        chromeView.onClose = { [weak self] in
            self?.close()
        }
        chromeView.onRetry = { [weak self] in
            self?.retry()
        }
        view.addSubview(chromeView)
        NSLayoutConstraint.activate([
            chromeView.topAnchor.constraint(equalTo: view.topAnchor),
            chromeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func beginScanningIfNeeded() {
        guard !didBeginScanning else { return }
        didBeginScanning = true
        applyPresentationState(.preparing)

        Task { [weak self] in
            let granted = await AIScanCameraController.requestCameraAccess()
            guard let self, !self.isClosed else { return }
            guard !Task.isCancelled else { return }
            guard granted else {
                self.fail(AIScanCameraViewControllerError.cameraPermissionDenied)
                return
            }

            do {
                try self.cameraController.configure()
            } catch {
                self.fail(error)
                return
            }

            self.cameraController.prepare(context: self.scanContext) { [weak self] error in
                let error = AIScanCameraCallbackValue(error)
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.isClosed else { return }
                    if let error = error.value {
                        self.fail(error)
                        return
                    }
                    self.applyPresentationState(.scanning)
                    self.cameraController.startRunning()
                }
            }
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        cameraController.cancel()
        onClose?()
        dismiss(animated: true)
    }

    private func retry() {
        guard !isClosed else { return }
        cameraController.reset()
        didBeginScanning = false
        beginScanningIfNeeded()
    }

    private func fail(_ error: Error) {
        guard !isClosed else { return }
        applyPresentationState(.error(AIScanCameraStrings.displayMessage(for: error)))
        onFailure?(error)
    }

    func applyPresentationState(_ state: AIScanCameraPresentationState) {
        chromeView.apply(state: state)
    }
}

@MainActor
extension AIScanCameraViewController: AIScanCameraControllerDelegate {
    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didUpdate evaluation: AISCFrameEvaluation
    ) {
        chromeView.setProgress(Float(evaluation.normalizedProgress), animated: true)
        applyPresentationState(evaluation.captureAllowed ? .ready : .scanning)
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didCapture evaluation: AISCFrameEvaluation
    ) {
        applyPresentationState(.analyzing)
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didProduce result: AISCDisplayResult
    ) {
        cameraController.stopRunning()
        applyPresentationState(.complete)
        onResult?(result)
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didFail error: Error
    ) {
        fail(error)
    }
}

enum AIScanCameraPresentationState: Equatable {
    case preparing
    case scanning
    case ready
    case analyzing
    case complete
    case error(String)
}

public enum AIScanCameraViewControllerError: LocalizedError {
    case cameraPermissionDenied

    public var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            AIScanCameraStrings.localized(.permissionDenied)
        }
    }
}

private struct AIScanCameraCallbackValue<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

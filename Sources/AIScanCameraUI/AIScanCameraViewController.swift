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

    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let captureButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didBeginScanning = false
    private var isClosed = false

    public init(configuration: AISCConfiguration, context: AISCScanContext) {
        self.cameraController = AIScanCameraController(configuration: configuration)
        self.scanContext = context
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        cameraController.delegate = self
        cameraController.automaticallyCapturesReadyFrames = true
        configureLayout()
        beginScanningIfNeeded()
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

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Preparing…"
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.accessibilityIdentifier = "aiscan.camera.status"

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.accessibilityIdentifier = "aiscan.camera.progress"

        var captureConfiguration = UIButton.Configuration.filled()
        captureConfiguration.image = UIImage(systemName: "camera.fill")
        captureConfiguration.baseBackgroundColor = .white
        captureConfiguration.baseForegroundColor = .black
        captureConfiguration.cornerStyle = .capsule
        captureButton.configuration = captureConfiguration
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.accessibilityLabel = "Capture"
        captureButton.accessibilityIdentifier = "aiscan.camera.capture"
        captureButton.isEnabled = false
        captureButton.addAction(UIAction { [weak self] _ in
            self?.cameraController.captureNextFrame()
        }, for: .touchUpInside)

        var closeConfiguration = UIButton.Configuration.plain()
        closeConfiguration.image = UIImage(systemName: "xmark")
        closeConfiguration.baseForegroundColor = .white
        closeButton.configuration = closeConfiguration
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.accessibilityLabel = "Close"
        closeButton.accessibilityIdentifier = "aiscan.camera.close"
        closeButton.addAction(UIAction { [weak self] _ in
            self?.close()
        }, for: .touchUpInside)

        view.addSubview(statusLabel)
        view.addSubview(progressView)
        view.addSubview(captureButton)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            statusLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            statusLabel.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -16),

            progressView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 48),
            progressView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -48),
            progressView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -28),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            captureButton.widthAnchor.constraint(equalToConstant: 72),
            captureButton.heightAnchor.constraint(equalToConstant: 72),
        ])
    }

    private func beginScanningIfNeeded() {
        guard !didBeginScanning else { return }
        didBeginScanning = true

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
                    self.statusLabel.text = "Scanning…"
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

    private func fail(_ error: Error) {
        guard !isClosed else { return }
        statusLabel.text = error.localizedDescription
        captureButton.isEnabled = false
        onFailure?(error)
    }
}

@MainActor
extension AIScanCameraViewController: AIScanCameraControllerDelegate {
    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didUpdate evaluation: AISCFrameEvaluation
    ) {
        progressView.setProgress(Float(evaluation.normalizedProgress), animated: true)
        captureButton.isEnabled = evaluation.captureAllowed
        statusLabel.text = evaluation.captureAllowed ? "Ready" : "Scanning…"
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didCapture evaluation: AISCFrameEvaluation
    ) {
        captureButton.isEnabled = false
        statusLabel.text = "Analyzing…"
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didProduce result: AISCDisplayResult
    ) {
        cameraController.stopRunning()
        statusLabel.text = "Complete"
        onResult?(result)
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didFail error: Error
    ) {
        fail(error)
    }
}

public enum AIScanCameraViewControllerError: LocalizedError {
    case cameraPermissionDenied

    public var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            "Camera permission is required to start a scan."
        }
    }
}

private struct AIScanCameraCallbackValue<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

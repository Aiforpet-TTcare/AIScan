@preconcurrency import AVFoundation
@preconcurrency import PhotosUI
import UniformTypeIdentifiers
import UIKit
@preconcurrency import AIScanCore

/// Host-presentable production camera controller for the high-level AIScan facade.
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
    private var requestedFlashEnabled = false
    private var temporaryAlbumImageURL: URL?
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
        cameraController.automaticallyCapturesReadyFrames = false
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
        chromeView.configure(
            partType: scanContext.partType,
            displaySubpart: scanContext.displaySubpart
        )
        chromeView.onCapture = { [weak self] in
            self?.cameraController.captureNextFrame()
        }
        chromeView.onClose = { [weak self] in
            self?.close()
        }
        chromeView.onRetry = { [weak self] in
            self?.retry()
        }
        chromeView.onFlashChanged = { [weak self] enabled in
            self?.requestedFlashEnabled = enabled
            try? self?.cameraController.setTorchEnabled(enabled)
        }
        chromeView.onAlbum = { [weak self] in
            self?.presentAlbumPicker()
        }
        chromeView.onStart = { [weak self] in
            guard let self else { return }
            self.cameraController.automaticallyCapturesReadyFrames = true
            try? self.cameraController.setTorchEnabled(self.requestedFlashEnabled)
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
                try? self.cameraController.setTorchEnabled(self.requestedFlashEnabled)
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
        removeTemporaryAlbumImage()
        onClose?()
        dismiss(animated: true)
    }

    private func retry() {
        guard !isClosed else { return }
        cameraController.reset()
        cameraController.automaticallyCapturesReadyFrames = false
        chromeView.resetStartPrompt()
        didBeginScanning = false
        beginScanningIfNeeded()
    }

    private func presentAlbumPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func diagnoseAlbumImage(at stagedURL: URL) {
        removeTemporaryAlbumImage()
        temporaryAlbumImageURL = stagedURL
        cameraController.stopRunning()
        applyPresentationState(.analyzing)
        cameraController.diagnoseImage(at: stagedURL)
    }

    private func removeTemporaryAlbumImage() {
        guard let temporaryAlbumImageURL else { return }
        try? FileManager.default.removeItem(at: temporaryAlbumImageURL)
        self.temporaryAlbumImageURL = nil
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
extension AIScanCameraViewController: PHPickerViewControllerDelegate {
    public func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else {
            cameraController.startRunning()
            return
        }
        guard
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            cameraController.startRunning()
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] sourceURL, error in
            var stagedURL: URL?
            var stagingError = error
            if let sourceURL, stagingError == nil {
                let fileExtension = sourceURL.pathExtension.isEmpty ? "img" : sourceURL.pathExtension
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("aiscan-album-\(UUID().uuidString)")
                    .appendingPathExtension(fileExtension)
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    stagedURL = destination
                } catch {
                    stagingError = error
                }
            }

            let value = AIScanCameraCallbackValue((stagedURL, stagingError))
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    if let stagedURL = value.value.0 {
                        try? FileManager.default.removeItem(at: stagedURL)
                    }
                    return
                }
                if let error = value.value.1 {
                    self.fail(error)
                    return
                }
                guard let stagedURL = value.value.0 else {
                    self.cameraController.startRunning()
                    return
                }
                self.diagnoseAlbumImage(at: stagedURL)
            }
        }
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
        removeTemporaryAlbumImage()
        applyPresentationState(.complete)
        onResult?(result)
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didFail error: Error
    ) {
        removeTemporaryAlbumImage()
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

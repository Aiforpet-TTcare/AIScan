@preconcurrency import AVFoundation
import UIKit
@preconcurrency import AIScanCore

/// Host-presentable camera controller backed by the original AIScan 2.2.4 UI.
/// Visible surfaces come from the original storyboards; this wrapper only
/// owns lifecycle and the Objective-C Core bridge.
@MainActor
public final class AIScanCameraViewController: UIViewController {
    public let cameraController: AIScanCameraController
    public let scanContext: AISCScanContext

    public var onResult: ((AISCDisplayResult) -> Void)?
    public var onFailure: ((Error) -> Void)?
    public var onClose: (() -> Void)?

    private let cameraSurface: CameraViewController
    private let overlayController: TTOverlayViewController
    private var guideController: PreviewGuideViewController?
    private var progressController: TTProgressViewController?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didBeginScanning = false
    private var didPrepareSession = false
    private var shouldRetryCameraPermissionWhenActive = false
    private var isClosed = false
    private var isTorchEnabled = false
    var beginsScanningAutomatically = true

    public init(configuration: AISCConfiguration, context: AISCScanContext) {
        cameraController = AIScanCameraController(configuration: configuration)
        scanContext = context
        cameraSurface = CameraViewController.instantiate(partType: context.partType)
        overlayController = TTOverlayViewController.instantiate(partType: context.partType)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        overrideUserInterfaceStyle = .dark
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        cameraController.delegate = self
        cameraController.automaticallyCapturesReadyFrames = false
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        installOriginalCameraUI()
        if beginsScanningAutomatically {
            if requiresSkinPositionSelection {
                showSkinPositionSelection()
            } else {
                beginScanningIfNeeded()
            }
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraSurface.preview.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraController.stopRunning()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cameraController.cancel()
    }

    @objc private func applicationDidBecomeActive() {
        guard shouldRetryCameraPermissionWhenActive, !isClosed else { return }
        shouldRetryCameraPermissionWhenActive = false
        didPrepareSession = false
        didBeginScanning = false
        cameraSurface.setPreparing(true)
        beginScanningIfNeeded()
    }

    private func installOriginalCameraUI() {
        addChild(cameraSurface)
        cameraSurface.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraSurface.view)
        NSLayoutConstraint.activate([
            cameraSurface.view.topAnchor.constraint(equalTo: view.topAnchor),
            cameraSurface.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraSurface.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraSurface.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        cameraSurface.didMove(toParent: self)

        addChild(overlayController)
        overlayController.view.translatesAutoresizingMaskIntoConstraints = false
        cameraSurface.overlayView.addSubview(overlayController.view)
        NSLayoutConstraint.activate([
            overlayController.view.topAnchor.constraint(equalTo: cameraSurface.overlayView.topAnchor),
            overlayController.view.leadingAnchor.constraint(equalTo: cameraSurface.overlayView.leadingAnchor),
            overlayController.view.trailingAnchor.constraint(equalTo: cameraSurface.overlayView.trailingAnchor),
            overlayController.view.bottomAnchor.constraint(equalTo: cameraSurface.overlayView.bottomAnchor),
        ])
        overlayController.didMove(toParent: self)

        let layer = cameraController.makePreviewLayer()
        layer.frame = cameraSurface.preview.bounds
        cameraSurface.preview.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        cameraSurface.onCapture = { [weak self] in
            self?.cameraSurface.setPreparing(true)
            self?.cameraController.captureNextFrame()
        }
        cameraSurface.onClose = { [weak self] in self?.close() }
        cameraSurface.onFlash = { [weak self] enabled in self?.setTorch(enabled) }
        cameraSurface.onGuide = { [weak self] in self?.showGuide() }
        cameraSurface.onSelectPart = { [weak self] in self?.showSkinPositionSelection() }
        cameraSurface.partSelectedContainer?.isHidden = scanContext.partType != .skin
        cameraSurface.setPreparing(true)
    }

    private func beginScanningIfNeeded() {
        guard !didBeginScanning else { return }
        didBeginScanning = true
        Task { [weak self] in
            let granted = await AIScanCameraController.requestCameraAccess()
            guard let self, !self.isClosed, !Task.isCancelled else { return }
            guard granted else {
                self.fail(AIScanCameraViewControllerError.cameraPermissionDenied)
                return
            }
            do { try self.cameraController.configure() } catch {
                self.fail(error)
                return
            }
            self.cameraController.prepare(context: self.scanContext) { [weak self] error in
                let callback = AIScanCameraCallbackValue(error)
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.isClosed else { return }
                    if let error = callback.value {
                        self.fail(error)
                        return
                    }
                    self.didPrepareSession = true
                    self.cameraSurface.setPreparing(false)
                    self.cameraController.startRunning()
                }
            }
        }
    }

    private func setTorch(_ enabled: Bool) {
        do {
            try cameraController.setTorchEnabled(enabled)
            isTorchEnabled = enabled
        } catch {
            cameraSurface.flashButton.isSelected = isTorchEnabled
            fail(error)
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
        dismissPresentedSurface { [weak self] in
            guard let self else { return }
            self.progressController = nil
            guard self.didPrepareSession else {
                self.didBeginScanning = false
                self.beginScanningIfNeeded()
                return
            }
            self.cameraController.reset()
            self.cameraSurface.setPreparing(false)
            self.cameraController.startRunning()
        }
    }

    private func fail(_ error: Error) {
        guard !isClosed else { return }
        cameraSurface.setPreparing(false)
        onFailure?(error)
        let permissionDenied = error is AIScanCameraViewControllerError
        let retryable = (error as NSError).userInfo[AISCRetryableKey] as? Bool == true
        let message = AIScanCameraStrings.displayMessage(for: error)
        dismissPresentedSurface { [weak self] in
            guard let self, !self.isClosed else { return }
            self.progressController = nil
            if permissionDenied {
                self.presentOriginalPermission(message: message)
            } else if retryable {
                self.presentOriginalRetry(message: message)
            } else {
                self.presentOriginalFailure(message: message)
            }
        }
    }

    private func presentOriginalPermission(message: String) {
        let popup = TTPopupAlertViewController.instantiate(
            title: message,
            primaryTitle: AIScanCameraStrings.localized(.settings),
            secondaryTitle: AIScanCameraStrings.localized(.close),
            primaryAccessibilityIdentifier: "aiscan.camera.settings",
            onPrimary: { [weak self] in self?.openCameraSettings() },
            onSecondary: { [weak self] in self?.close() }
        )
        present(AIScanLegacyPopupContainer(content: popup), animated: true)
    }

    private func openCameraSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        shouldRetryCameraPermissionWhenActive = true
        UIApplication.shared.open(url)
    }

    private func presentOriginalRetry(message: String) {
        let popup = TTPopupAlertViewController.instantiate(
            title: message,
            primaryTitle: AIScanCameraStrings.localized(.retry),
            secondaryTitle: AIScanCameraStrings.localized(.close),
            onPrimary: { [weak self] in self?.retry() },
            onSecondary: { [weak self] in self?.close() }
        )
        present(AIScanLegacyPopupContainer(content: popup), animated: true)
    }

    private func presentOriginalFailure(message: String) {
        let popup = TTPopupAlertViewController.instantiate(
            title: message,
            primaryTitle: AIScanCameraStrings.localized(.close),
            secondaryTitle: nil,
            onPrimary: { [weak self] in self?.close() },
            onSecondary: nil
        )
        present(AIScanLegacyPopupContainer(content: popup), animated: true)
    }

    private func showGuide() {
        guard guideController == nil else { return }
        let guide = PreviewGuideViewController.instantiate(context: scanContext)
        guideController = guide
        guide.onDismiss = { [weak self, weak guide] in
            guard let self, let guide else { return }
            guide.willMove(toParent: nil)
            guide.view.removeFromSuperview()
            guide.removeFromParent()
            self.guideController = nil
        }
        addChild(guide)
        guide.view.translatesAutoresizingMaskIntoConstraints = false
        cameraSurface.overlayView.addSubview(guide.view)
        NSLayoutConstraint.activate([
            guide.view.topAnchor.constraint(equalTo: cameraSurface.overlayView.topAnchor),
            guide.view.leadingAnchor.constraint(equalTo: cameraSurface.overlayView.leadingAnchor),
            guide.view.trailingAnchor.constraint(equalTo: cameraSurface.overlayView.trailingAnchor),
            guide.view.bottomAnchor.constraint(equalTo: cameraSurface.overlayView.bottomAnchor),
        ])
        guide.didMove(toParent: self)
    }

    private var requiresSkinPositionSelection: Bool {
        scanContext.partType == .skin && scanContext.analysisPosition == nil
    }

    private func showSkinPositionSelection() {
        guard scanContext.partType == .skin, presentedViewController == nil else { return }
        cameraController.stopRunning()
        let selector = TTPopupSelectedSkinViewController.instantiate(
            onStart: { [weak self] position, flashEnabled in
                guard let self else { return }
                self.scanContext.analysisPosition = position
                self.scanContext.analysisSubpart = nil
                self.scanContext.displaySubpart = position.uppercased()
                self.cameraSurface.partSelectedContainer?.isHidden = false
                if flashEnabled { self.setTorch(true) }
                if self.didBeginScanning {
                    self.cameraController.reset()
                    self.cameraController.startRunning()
                } else {
                    self.beginScanningIfNeeded()
                }
            },
            onClose: { [weak self] in
                guard let self else { return }
                if self.didBeginScanning { self.cameraController.startRunning() }
            }
        )
        present(
            AIScanLegacyPopupContainer(
                content: selector,
                cardWidth: 316
            ),
            animated: true
        )
    }

    private func showProgressIfNeeded() -> TTProgressViewController {
        if let progressController { return progressController }
        let progress = TTProgressViewController.instantiate()
        progressController = progress
        present(progress, animated: false)
        return progress
    }

    private func dismissPresentedSurface(completion: @escaping () -> Void) {
        guard let presentedViewController else {
            completion()
            return
        }
        presentedViewController.dismiss(animated: true, completion: completion)
    }
}

@MainActor
extension AIScanCameraViewController: AIScanCameraControllerDelegate {
    public func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation) {
        overlayController.apply(evaluation: evaluation)
        cameraSurface.captureButton.isEnabled = evaluation.captureAllowed
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation) {
        cameraSurface.flashCapture()
        cameraSurface.setPreparing(true)
        cameraController.stopRunning()
        showProgressIfNeeded().set(progress: 0, animated: false)
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didUpdateDiagnosisProgress progress: Double) {
        showProgressIfNeeded().set(progress: progress, animated: true)
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult) {
        cameraController.stopRunning()
        showProgressIfNeeded().set(progress: 1, animated: true)
        if result.contractResult != nil {
            onResult?(result)
            isClosed = true
            cameraController.cancel()
            dismiss(animated: true)
            return
        }
        dismissPresentedSurface { [weak self] in
            guard let self, !self.isClosed else { return }
            self.progressController = nil
            self.onResult?(result)
        }
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error) {
        fail(error)
    }
}

public enum AIScanCameraViewControllerError: LocalizedError {
    case cameraPermissionDenied

    public var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied: AIScanCameraStrings.localized(.permissionDenied)
        }
    }
}

private struct AIScanCameraCallbackValue<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

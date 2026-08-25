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
    private var isCaptureAttemptActive = false
    private var captureAttemptStartedAt: Date?
    private var captureAttemptTimer: Timer?
    private var didPresentInitialGuidance = false
    private var didPresentSkinPositionSelection = false
    let captureAttemptDuration: TimeInterval = 60
    var beginsScanningAutomatically = true

    public init(configuration: AISCConfiguration, context: AISCScanContext) {
        self.cameraController = AIScanCameraController(configuration: configuration)
        self.scanContext = context
        self.cameraSurface = CameraViewController.instantiate(partType: context.partType)
        self.overlayController = TTOverlayViewController.instantiate(partType: context.partType)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        overrideUserInterfaceStyle = .dark
    }

    init(cameraController: AIScanCameraController, context: AISCScanContext) {
        self.cameraController = cameraController
        scanContext = context
        cameraSurface = CameraViewController.instantiate(partType: context.partType)
        overlayController = TTOverlayViewController.instantiate(partType: context.partType)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        overrideUserInterfaceStyle = .dark
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    public override var shouldAutorotate: Bool { false }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    public override var prefersStatusBarHidden: Bool { true }

    public override var prefersHomeIndicatorAutoHidden: Bool { true }

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
        MainActor.assumeIsolated {
            captureAttemptTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }
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
            self?.toggleCaptureAttempt()
        }
        cameraSurface.onClose = { [weak self] in self?.close() }
        cameraSurface.onFlash = { [weak self] enabled in self?.setTorch(enabled) }
        cameraSurface.onGuide = { [weak self] in self?.showGuide(automatic: false) }
        cameraSurface.onSelectPart = { [weak self] in self?.showSkinPositionSelection() }
        cameraSurface.onZoom = { [weak self] scale in
            do {
                try self?.cameraController.scaleZoom(by: scale)
            } catch {
                guard !(error is AIScanCameraControllerError) else { return }
                self?.fail(error)
            }
        }
        cameraSurface.configureControls(
            showsPartSelector: scanContext.partType == .skin,
            showsGuide: scanContext.partType != .joint
        )
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
                    self.cameraSurface.captureButton.isEnabled = true
                    self.overlayController.setMessage(
                        AIScanCameraStrings.localized(.startPrompt)
                    )
                    self.cameraController.startRunning()
                    self.presentInitialGuidanceIfNeeded()
                }
            }
        }
    }

    private func presentInitialGuidanceIfNeeded() {
        guard !didPresentInitialGuidance, !isClosed else { return }
        didPresentInitialGuidance = true
        if scanContext.partType == .skin, didPresentSkinPositionSelection {
            return
        }
        guard scanContext.partType != .joint else {
            showGuide(automatic: true)
            return
        }
        if scanContext.displayMetadata?["show_flash_warning"] == "false" {
            showGuide(automatic: true)
            return
        }
        let popup = TTFlashWarningAlertViewController.instantiate(
            showsSkinGuidance: scanContext.partType == .skin,
            startsWithFlash: isTorchEnabled,
            onStart: { [weak self] flashEnabled in
                guard let self else { return }
                if flashEnabled != self.isTorchEnabled {
                    self.setTorch(flashEnabled)
                }
                self.showGuide(automatic: true)
            }
        )
        present(
            AIScanLegacyPopupContainer(
                content: popup,
                cardHeight: 388
            ),
            animated: true
        )
    }

    private func toggleCaptureAttempt() {
        guard didPrepareSession, presentedViewController == nil else { return }
        if isCaptureAttemptActive {
            cancelCaptureAttempt()
        } else {
            beginCaptureAttempt()
        }
    }

    private func beginCaptureAttempt() {
        guard !isCaptureAttemptActive else { return }
        isCaptureAttemptActive = true
        captureAttemptStartedAt = Date()
        cameraController.automaticallyCapturesReadyFrames = true
        cameraSurface.setCaptureAttempt(active: true)
        cameraSurface.captureButton.isEnabled = true
        startCaptureAttemptTimer()
    }

    private func cancelCaptureAttempt() {
        cameraController.automaticallyCapturesReadyFrames = false
        cameraController.reset()
        finishCaptureAttemptUI()
        overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
    }

    private func finishCaptureAttemptUI() {
        isCaptureAttemptActive = false
        captureAttemptStartedAt = nil
        cameraController.automaticallyCapturesReadyFrames = false
        stopCaptureAttemptTimer()
        cameraSurface.setCaptureAttempt(active: false)
    }

    private func startCaptureAttemptTimer() {
        stopCaptureAttemptTimer()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateCaptureAttemptTimer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        captureAttemptTimer = timer
        updateCaptureAttemptTimer()
    }

    private func stopCaptureAttemptTimer() {
        captureAttemptTimer?.invalidate()
        captureAttemptTimer = nil
    }

    private func updateCaptureAttemptTimer() {
        guard isCaptureAttemptActive, let captureAttemptStartedAt else { return }
        let elapsed = Date().timeIntervalSince(captureAttemptStartedAt)
        cameraSurface.setCaptureAttempt(
            active: true,
            progress: CGFloat(elapsed / captureAttemptDuration)
        )
        guard elapsed >= captureAttemptDuration else { return }
        cameraController.reset()
        finishCaptureAttemptUI()
        overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
        let popup = TTPopupTimeoverViewController.instantiate(
            onRetry: { [weak self] in self?.beginCaptureAttempt() },
            onGuide: { [weak self] in self?.showGuide(automatic: false) }
        )
        present(
            AIScanLegacyPopupContainer(
                content: popup,
                cardHeight: 263
            ),
            animated: true
        )
    }

    private func setTorch(_ enabled: Bool) {
        do {
            try cameraController.setTorchEnabled(enabled)
            isTorchEnabled = enabled
            cameraSurface.setFlashEnabled(enabled)
        } catch {
            cameraSurface.flashButton.isSelected = isTorchEnabled
            fail(error)
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        stopCaptureAttemptTimer()
        cameraController.cancel()
        onClose?()
        dismiss(animated: true)
    }

    private func retry() {
        guard !isClosed else { return }
        dismissPresentedSurface { [weak self] in
            guard let self else { return }
            self.progressController = nil
            self.finishCaptureAttemptUI()
            guard self.didPrepareSession else {
                self.didBeginScanning = false
                self.beginScanningIfNeeded()
                return
            }
            self.cameraController.reset()
            self.cameraSurface.setPreparing(false)
            self.cameraSurface.captureButton.isEnabled = true
            self.overlayController.setMessage(
                AIScanCameraStrings.localized(.startPrompt)
            )
            self.cameraController.startRunning()
        }
    }

    private func fail(_ error: Error) {
        guard !isClosed else { return }
        cameraSurface.setPreparing(false)
        finishCaptureAttemptUI()
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
            title: AIScanCameraStrings.localized(.notice),
            subtitle: message,
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
            title: AIScanCameraStrings.localized(.notice),
            subtitle: message,
            primaryTitle: AIScanCameraStrings.localized(.retry),
            secondaryTitle: AIScanCameraStrings.localized(.close),
            onPrimary: { [weak self] in self?.retry() },
            onSecondary: { [weak self] in self?.close() }
        )
        present(AIScanLegacyPopupContainer(content: popup), animated: true)
    }

    private func presentOriginalFailure(message: String) {
        let popup = TTPopupAlertViewController.instantiate(
            title: AIScanCameraStrings.localized(.notice),
            subtitle: message,
            primaryTitle: AIScanCameraStrings.localized(.close),
            secondaryTitle: nil,
            onPrimary: { [weak self] in self?.close() },
            onSecondary: nil
        )
        present(AIScanLegacyPopupContainer(content: popup), animated: true)
    }

    private func showGuide(automatic: Bool = false) {
        guard guideController == nil else { return }
        if automatic, !shouldShowAutomaticGuideToday {
            cameraSurface.startCaptureButtonAttentionAnimation()
            overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
            return
        }
        if automatic {
            UserDefaults.standard.set(currentGuideDate, forKey: automaticGuideDefaultsKey)
        }
        let guide = PreviewGuideViewController.instantiate(context: scanContext)
        guideController = guide
        guide.onDismiss = { [weak self, weak guide] in
            guard let self, let guide else { return }
            guide.willMove(toParent: nil)
            guide.view.removeFromSuperview()
            guide.removeFromParent()
            self.guideController = nil
            self.overlayController.setMessage(
                AIScanCameraStrings.localized(.startPrompt)
            )
            self.cameraSurface.startCaptureButtonAttentionAnimation()
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
        didPresentSkinPositionSelection = true
        cameraController.stopRunning()
        let selector = TTPopupSelectedSkinViewController.instantiate(
            onStart: { [weak self] position, flashEnabled in
                guard let self else { return }
                self.scanContext.analysisPosition = position
                self.scanContext.analysisSubpart = nil
                self.scanContext.displaySubpart = position.uppercased()
                self.cameraSurface.partSelectedContainer?.isHidden = false
                if flashEnabled { self.setTorch(true) }
                self.showGuide(automatic: true)
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

    private var currentGuideDate: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var automaticGuideDefaultsKey: String {
        let pet = scanContext.petType == .cat ? "cat" : "dog"
        let part: String
        switch scanContext.partType {
        case .eye: part = "eye"
        case .teeth: part = "teeth"
        case .skin: part = scanContext.analysisPosition ?? "skin"
        case .joint: part = "joint"
        default: part = "unknown"
        }
        return "com.aiforpet.didShowPreviewGuide.\(pet).\(part)"
    }

    private var shouldShowAutomaticGuideToday: Bool {
        UserDefaults.standard.string(forKey: automaticGuideDefaultsKey) != currentGuideDate
    }
}

@MainActor
extension AIScanCameraViewController: AIScanCameraControllerDelegate {
    public func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation) {
        if isCaptureAttemptActive {
            overlayController.apply(evaluation: evaluation)
        } else {
            overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
        }
        cameraSurface.captureButton.isEnabled = didPrepareSession
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation) {
        finishCaptureAttemptUI()
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

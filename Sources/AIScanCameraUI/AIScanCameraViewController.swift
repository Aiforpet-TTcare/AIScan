@preconcurrency import AVFoundation
import SwiftUI
import UIKit
@preconcurrency import AIScanCore

enum AIScanCameraStackDismissalTransition: Equatable {
    case immediate
    case coordinatedCrossDissolve(duration: TimeInterval)
}

struct AIScanCameraStackTransitionPolicy {
    static func allowsCoordinatedTransition(
        duration: TimeInterval,
        animationsEnabled: Bool,
        reduceMotionEnabled: Bool,
        applicationIsActive: Bool,
        hasVisibleWindow: Bool
    ) -> Bool {
        duration > 0
            && animationsEnabled
            && !reduceMotionEnabled
            && applicationIsActive
            && hasVisibleWindow
    }
}

@MainActor
protocol AIScanCameraStackDismissing: AnyObject {
    func dismissStack(
        from camera: UIViewController,
        transition: AIScanCameraStackDismissalTransition,
        completion: @escaping () -> Void
    )
}

@MainActor
protocol AIScanTransientSurfaceCoordinating: AIScanLegacyPopupDismissing {
    func dismissPresentedSurface(
        from presenter: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    )

    func present(
        _ surface: UIViewController,
        from presenter: UIViewController,
        animated: Bool
    )
}

@MainActor
private final class AIScanUIKitTransientSurfaceCoordinator: AIScanTransientSurfaceCoordinating {
    func dismissPresentedSurface(
        from presenter: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        guard let surface = presenter.presentedViewController else {
            completion()
            return
        }
        surface.dismiss(animated: animated, completion: completion)
    }

    func present(
        _ surface: UIViewController,
        from presenter: UIViewController,
        animated: Bool
    ) {
        presenter.present(surface, animated: animated)
    }

    func dismiss(
        _ container: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        container.dismiss(animated: animated, completion: completion)
    }
}

@MainActor
private final class AIScanUIKitCameraStackDismisser: AIScanCameraStackDismissing {
    func dismissStack(
        from camera: UIViewController,
        transition: AIScanCameraStackDismissalTransition,
        completion: @escaping () -> Void
    ) {
        let dismissWithoutAnimation: (() -> Void)?
        if let presentingViewController = camera.presentingViewController {
            dismissWithoutAnimation = {
                presentingViewController.dismiss(animated: false)
            }
        } else if let presentedViewController = camera.presentedViewController {
            dismissWithoutAnimation = {
                presentedViewController.dismiss(animated: false)
            }
        } else {
            dismissWithoutAnimation = nil
        }

        guard let dismissWithoutAnimation else {
            completion()
            return
        }

        switch transition {
        case .immediate:
            dismissWithoutAnimation()
            completion()
        case let .coordinatedCrossDissolve(duration):
            let window = camera.viewIfLoaded?.window
            guard AIScanCameraStackTransitionPolicy.allowsCoordinatedTransition(
                duration: duration,
                animationsEnabled: UIView.areAnimationsEnabled,
                reduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
                applicationIsActive: UIApplication.shared.applicationState == .active,
                hasVisibleWindow: window?.isHidden == false
            ), let window else {
                dismissWithoutAnimation()
                completion()
                return
            }
            UIView.transition(
                with: window,
                duration: min(duration, 0.2),
                options: [.transitionCrossDissolve, .beginFromCurrentState, .allowAnimatedContent],
                animations: dismissWithoutAnimation,
                completion: { _ in completion() }
            )
        }
    }
}

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
    private let stackDismisser: AIScanCameraStackDismissing
    private let transientSurfaceCoordinator: AIScanTransientSurfaceCoordinating
    private let settingsOpener: @MainActor () -> Void
    private let allowsSkinPositionSelection: Bool
    private let allowsAlbum: Bool
    private var guideController: PreviewGuideViewController?
    private var progressController: TTProgressViewController?
    private var questionnaireController: UIViewController?
    private var pendingQuestionnaire: AISCQuestionnaire?
    private var albumController: AIScanAlbumSelectionViewController?
    private var isAlbumSelectionPresented = false
    private var isAlbumTransitioningToProgress = false
    private var pendingAlbumRestoration = false
    private var capturedPreviewImage: UIImage?
    private var pendingAlbumProgress: Double?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didBeginScanning = false
    private var didPrepareSession = false
    private var shouldRetryCameraPermissionWhenActive = false
    private var isCameraSessionRunning = false
    private var shouldResumeCameraAfterForeground = false
    private var isApplicationInBackground = false
    private var isClosed = false
    private var isTorchEnabled = false
    private var captureAttemptState = AIScanCaptureAttemptState()
    private var captureAttemptTimer: Timer?
    private var didPresentInitialGuidance = false
    private var didPresentSkinPositionSelection = false
    private var shouldShowSkinGuideAfterPreparation = false
    private var requestedTorchEnabled = false
    private var isDiagnosingAlbum = false
    private let monotonicTime: () -> TimeInterval
    let captureAttemptDuration: TimeInterval = 60
    var beginsScanningAutomatically = true

    public convenience init(
        configuration: AISCConfiguration,
        context: AISCScanContext,
        allowsAlbum: Bool = true
    ) {
        self.init(
            cameraController: AIScanCameraController(configuration: configuration),
            context: context,
            stackDismisser: AIScanUIKitCameraStackDismisser(),
            allowsAlbum: allowsAlbum
        )
    }

    convenience init(cameraController: AIScanCameraController, context: AISCScanContext) {
        self.init(
            cameraController: cameraController,
            context: context,
            stackDismisser: AIScanUIKitCameraStackDismisser()
        )
    }

    init(
        cameraController: AIScanCameraController,
        context: AISCScanContext,
        stackDismisser: AIScanCameraStackDismissing,
        transientSurfaceCoordinator: AIScanTransientSurfaceCoordinating? = nil,
        allowsAlbum: Bool = true,
        settingsOpener: @escaping @MainActor () -> Void = {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        },
        monotonicTime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.cameraController = cameraController
        scanContext = context
        cameraSurface = CameraViewController.instantiate(partType: context.partType)
        overlayController = TTOverlayViewController.instantiate(partType: context.partType)
        self.stackDismisser = stackDismisser
        self.transientSurfaceCoordinator = transientSurfaceCoordinator
            ?? AIScanUIKitTransientSurfaceCoordinator()
        self.settingsOpener = settingsOpener
        allowsSkinPositionSelection = context.partType == .skin
            && context.analysisPosition == nil
        self.allowsAlbum = allowsAlbum
        self.monotonicTime = monotonicTime
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        installOriginalCameraUI()
        if beginsScanningAutomatically {
            if !requiresSkinPositionSelection {
                beginScanningIfNeeded()
            }
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard beginsScanningAutomatically,
              requiresSkinPositionSelection,
              !didPresentSkinPositionSelection else { return }
        showSkinPositionSelection()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraSurface.preview.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
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
        captureAttemptState.prepareForRetry()
        didPrepareSession = false
        didBeginScanning = false
        cameraSurface.setPreparing(true)
        beginScanningIfNeeded()
    }

    @objc private func applicationDidEnterBackground() {
        guard !isClosed else { return }
        isApplicationInBackground = true
        let wasRunning = isCameraSessionRunning
        shouldResumeCameraAfterForeground = wasRunning
        if captureAttemptState.isActive {
            cancelCaptureAttempt()
        }
        if wasRunning {
            stopCameraSession()
        }
    }

    @objc private func applicationWillEnterForeground() {
        isApplicationInBackground = false
        guard shouldResumeCameraAfterForeground else { return }
        shouldResumeCameraAfterForeground = false
        guard didPrepareSession, !isClosed else { return }
        startCameraSession()
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

        cameraSurface.addChild(overlayController)
        overlayController.view.translatesAutoresizingMaskIntoConstraints = false
        cameraSurface.overlayView.addSubview(overlayController.view)
        NSLayoutConstraint.activate([
            overlayController.view.topAnchor.constraint(equalTo: cameraSurface.overlayView.topAnchor),
            overlayController.view.leadingAnchor.constraint(equalTo: cameraSurface.overlayView.leadingAnchor),
            overlayController.view.trailingAnchor.constraint(equalTo: cameraSurface.overlayView.trailingAnchor),
            overlayController.view.bottomAnchor.constraint(equalTo: cameraSurface.overlayView.bottomAnchor),
        ])
        overlayController.didMove(toParent: cameraSurface)

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
        cameraSurface.onAlbum = { [weak self] in self?.showAlbumSelection() }
        cameraSurface.onZoom = { [weak self] scale in
            do {
                try self?.cameraController.scaleZoom(by: scale)
            } catch {
                guard !(error is AIScanCameraControllerError) else { return }
                self?.fail(error)
            }
        }
        cameraSurface.configureControls(
            showsPartSelector: allowsSkinPositionSelection,
            showsGuide: true,
            showsAlbum: allowsAlbum
        )
        cameraSurface.setPreparing(true)
    }

    private func beginScanningIfNeeded() {
        guard !didBeginScanning else { return }
        didBeginScanning = true
        Task { [weak self] in
            let granted = await self?.cameraController.requestCameraAccess() ?? false
            guard let self, !self.isClosed, !Task.isCancelled else { return }
            guard granted else {
                self.fail(AIScanCameraViewControllerError.cameraPermissionDenied)
                return
            }
            self.cameraController.prepare(
                context: self.scanContext,
                detailedProgress: { [weak self] progress in
                    DispatchQueue.main.async { [weak self] in
                        self?.showDownloadProgress(progress)
                    }
                }
            ) { [weak self] error in
                let callback = AIScanCameraCallbackValue(error)
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.isClosed else { return }
                    if let error = callback.value {
                        self.fail(error)
                        return
                    }
                    do {
                        try self.cameraController.configure()
                    } catch {
                        self.fail(error)
                        return
                    }
                    if self.requestedTorchEnabled {
                        self.setTorch(true)
                    }
                    self.finishPreparationFlow()
                }
            }
        }
    }

    private func showDownloadProgress(_ progress: AIScanPreparationProgressSnapshot) {
        guard !isClosed else { return }
        let controller: TTProgressViewController
        if let progressController, progressController.isDownloadProgress {
            controller = progressController
        } else {
            guard presentedViewController == nil else { return }
            controller = TTProgressViewController.instantiateDownload()
            progressController = controller
            cameraSurface.setPreparationIndicatorAnimating(false)
            present(controller, animated: true)
        }
        controller.set(downloadProgress: progress, animated: true)
    }

    private func finishPreparationFlow() {
        didPrepareSession = true
        let showsSkinGuide = shouldShowSkinGuideAfterPreparation
        shouldShowSkinGuideAfterPreparation = false
        let activateCamera = { [weak self] in
            guard let self, !self.isClosed else { return }
            self.progressController = nil
            self.cameraSurface.setPreparing(false)
            self.overlayController.setMessage(
                AIScanCameraStrings.localized(.startPrompt)
            )
            self.startCameraSession()
            if showsSkinGuide {
                self.showGuide(automatic: true)
            } else {
                self.presentInitialGuidanceIfNeeded()
            }
        }
        guard let progressController, progressController.isDownloadProgress else {
            activateCamera()
            return
        }
        progressController.set(progress: 1, animated: true)
        progressController.dismiss(animated: true, completion: activateCamera)
    }

    private func presentInitialGuidanceIfNeeded() {
        guard !didPresentInitialGuidance, !isClosed else { return }
        didPresentInitialGuidance = true
        if scanContext.partType == .skin, didPresentSkinPositionSelection {
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
            AIScanLegacyPopupContainer(content: popup),
            animated: false
        )
    }

    private func toggleCaptureAttempt() {
        guard didPrepareSession,
              presentedViewController == nil else { return }
        guideController?.dismissGuide()
        guard guideController == nil else { return }
        if captureAttemptState.isActive {
            cancelCaptureAttempt()
        } else {
            beginCaptureAttempt()
        }
    }

    func beginCaptureAttempt() {
        guard captureAttemptState.begin(at: monotonicTime()) else { return }
        capturedPreviewImage = nil
        cameraController.beginCaptureAttempt()
        cameraController.automaticallyCapturesReadyFrames = true
        cameraSurface.setCaptureAttempt(active: true)
        startCaptureAttemptTimer()
    }

    private func cancelCaptureAttempt() {
        captureAttemptState.cancel()
        cameraController.automaticallyCapturesReadyFrames = false
        cameraController.resetCaptureAttempt()
        stopCaptureAttemptUI()
        overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
    }

    private func stopCaptureAttemptUI() {
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

    func updateCaptureAttemptTimer() {
        switch captureAttemptState.update(
            at: monotonicTime(),
            duration: captureAttemptDuration
        ) {
        case .inactive:
            return
        case let .progress(progress):
            cameraSurface.setCaptureAttempt(active: true, progress: CGFloat(progress))
            return
        case .timedOut:
            cameraController.captureAttemptTimedOut()
        }
        cameraController.resetCaptureAttempt()
        stopCaptureAttemptUI()
        overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
        let popup = TTPopupTimeoverViewController.instantiate(
            onRetry: { [weak self] in self?.beginCaptureAttempt() },
            onGuide: { [weak self] in self?.showGuide(automatic: false) }
        )
        let container = AIScanLegacyPopupContainer(
            content: popup,
            popupDismisser: transientSurfaceCoordinator
        )
        transientSurfaceCoordinator.present(
            container,
            from: self,
            animated: false
        )
    }

    private func setTorch(_ enabled: Bool) {
        do {
            try cameraController.setTorchEnabled(enabled)
            isTorchEnabled = enabled
            cameraSurface.setFlashEnabled(enabled)
        } catch AIScanCameraControllerError.torchUnavailable {
            isTorchEnabled = false
            cameraSurface.setFlashAvailable(false)
        } catch {
            cameraSurface.flashButton.isSelected = isTorchEnabled
            fail(error)
        }
    }

    private func startCameraSession() {
        guard !isClosed else { return }
        guard !isApplicationInBackground else {
            shouldResumeCameraAfterForeground = didPrepareSession
            return
        }
        guard !isCameraSessionRunning else { return }
        isCameraSessionRunning = true
        cameraController.startRunning()
        overlayController.setCameraActive(true)
    }

    private func stopCameraSession() {
        isCameraSessionRunning = false
        overlayController.setCameraActive(false)
        cameraController.stopRunning()
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        removeQuestionnaire()
        pendingQuestionnaire = nil
        captureAttemptState.cancel()
        stopCaptureAttemptUI()
        cameraController.cancel()
        onClose?()
        dismiss(animated: true)
    }

    private func retry() {
        guard !isClosed else { return }
        removeQuestionnaire()
        pendingQuestionnaire = nil
        dismissPresentedSurface { [weak self] in
            guard let self else { return }
            self.progressController = nil
            self.captureAttemptState.prepareForRetry()
            self.stopCaptureAttemptUI()
            guard self.didPrepareSession else {
                self.didBeginScanning = false
                self.beginScanningIfNeeded()
                return
            }
            self.reprepareCurrentSession()
        }
    }

    private func fail(_ error: Error) {
        guard !isClosed else { return }
        guard captureAttemptState.markFailed() else { return }
        removeQuestionnaire()
        pendingQuestionnaire = nil
        cameraSurface.setPreparing(false)
        stopCaptureAttemptUI()
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
        present(
            AIScanLegacyPopupContainer(
                content: popup,
                popupDismisser: transientSurfaceCoordinator
            ),
            animated: false
        )
    }

    private func openCameraSettings() {
        shouldRetryCameraPermissionWhenActive = true
        settingsOpener()
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
        present(AIScanLegacyPopupContainer(content: popup), animated: false)
    }

    private func presentOriginalRetake(reasonCode: String?) {
        let item = AIScanRetakeGuideItem(
            title: retakeTitle(for: reasonCode),
            wrongTitle: AIScanCameraStrings.localized(.retakeWrong),
            rightTitle: AIScanCameraStrings.localized(.retakeRight),
            wrongImage: capturedPreviewImage ?? retakeGuideImage(suffix: "1"),
            rightImage: retakeGuideImage(suffix: "2")
        )
        let popup = TTPopupCheckedResultViewController.instantiate(
            item: item,
            onRetake: { [weak self] in
                guard let self, !self.isClosed else { return }
                guard self.captureAttemptState.prepareForRetry() else { return }
                self.cameraController.resetCaptureAttempt()
                self.cameraSurface.setPreparing(false)
                self.overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
            }
        )
        transientSurfaceCoordinator.present(
            AIScanLegacyBottomPopupContainer(
                content: popup,
                popupDismisser: transientSurfaceCoordinator
            ),
            from: self,
            animated: true
        )
    }

    private func retakeTitle(for reasonCode: String?) -> String {
        let code = reasonCode?.uppercased() ?? ""
        if code.contains("BBOX_TOO_SMALL") || code.contains("TOO_FAR") {
            return AIScanCameraStrings.localizedMessageKey("move_closer")
        }
        if code.contains("BBOX_TOO_LARGE") || code.contains("TOO_CLOSE") {
            return AIScanCameraStrings.localizedMessageKey("move_farther")
        }
        if code.contains("BLUR") || code.contains("CBLUR") {
            return AIScanCameraStrings.localizedMessageKey("hold_still")
        }
        return AIScanCameraStrings.localized(.retakeTitle)
    }

    private func retakeGuideImage(suffix: String) -> UIImage? {
        let base: String
        switch scanContext.partType {
        case .eye:
            base = scanContext.petType == .cat ? "cat_eye" : "dog_eye"
        case .teeth:
            base = scanContext.petType == .cat ? "cat_teeth" : "dog_teeth"
        case .skin:
            switch scanContext.analysisPosition?.lowercased() {
            case "ear": base = "dog_ear"
            case "foot", "paw": base = "dog_paw"
            default: base = "dog_body"
            }
        default:
            return nil
        }
        return UIImage(
            named: "\(base)\(suffix)",
            in: AIScanCameraResourceBundle.bundle,
            compatibleWith: nil
        )
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
        present(AIScanLegacyPopupContainer(content: popup), animated: false)
    }

    private func showGuide(automatic: Bool = false) {
        if !automatic {
            showWebGuide()
            return
        }
        guard guideController == nil else { return }
        if automatic, !shouldShowAutomaticGuide {
            cameraSurface.startCaptureButtonAttentionAnimation()
            overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
            return
        }
        if automatic {
            UserDefaults.standard.set(true, forKey: automaticGuideDefaultsKey)
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
        cameraSurface.addChild(guide)
        guide.view.translatesAutoresizingMaskIntoConstraints = false
        cameraSurface.overlayView.addSubview(guide.view)
        NSLayoutConstraint.activate([
            guide.view.topAnchor.constraint(equalTo: cameraSurface.overlayView.topAnchor),
            guide.view.leadingAnchor.constraint(equalTo: cameraSurface.overlayView.leadingAnchor),
            guide.view.trailingAnchor.constraint(equalTo: cameraSurface.overlayView.trailingAnchor),
            guide.view.bottomAnchor.constraint(equalTo: cameraSurface.overlayView.bottomAnchor),
        ])
        guide.didMove(toParent: cameraSurface)
    }

    private func showWebGuide() {
        guard presentedViewController == nil,
              let url = AIScanCameraGuideURL.make(context: scanContext) else {
            return
        }
        let guide = TTCameraGuideViewController.instantiate(url: url)
        guide.onDismiss = { [weak self] in
            guard let self, self.didPrepareSession, !self.isClosed else { return }
            self.startCameraSession()
        }
        present(guide, animated: true)
    }

    private var requiresSkinPositionSelection: Bool {
        allowsSkinPositionSelection && scanContext.analysisPosition == nil
    }

    func showSkinPositionSelection() {
        guard allowsSkinPositionSelection, presentedViewController == nil else { return }
        let isRequiredBeforeFirstPreparation = requiresSkinPositionSelection
            && !didBeginScanning
        didPresentSkinPositionSelection = true
        stopCameraSession()
        let selector = TTPopupSelectedSkinViewController.instantiate(
            initialPosition: scanContext.analysisPosition ?? "belly",
            startsWithFlash: isTorchEnabled || requestedTorchEnabled,
            onStart: { [weak self] position, flashEnabled in
                guard let self else { return }
                let positionChanged = self.scanContext.analysisPosition != position
                self.scanContext.analysisPosition = position
                self.scanContext.analysisSubpart = nil
                self.scanContext.displaySubpart = position.uppercased()
                self.cameraSurface.partSelectedContainer?.isHidden = false
                self.requestedTorchEnabled = flashEnabled
                self.shouldShowSkinGuideAfterPreparation = true
                if self.didBeginScanning {
                    if positionChanged {
                        self.reprepareCurrentSession()
                    } else {
                        if flashEnabled != self.isTorchEnabled {
                            self.setTorch(flashEnabled)
                        }
                        self.shouldShowSkinGuideAfterPreparation = false
                        self.startCameraSession()
                        self.showGuide(automatic: true)
                    }
                } else {
                    self.beginScanningIfNeeded()
                }
            },
            onClose: { [weak self] in
                guard let self else { return }
                if isRequiredBeforeFirstPreparation {
                    self.close()
                } else if self.didBeginScanning {
                    self.startCameraSession()
                }
            }
        )
        present(
            AIScanLegacyPopupContainer(
                content: selector,
                cardWidth: 316,
                cardCornerRadius: 20,
                presentationSpringDamping: 0.75
            ),
            animated: false
        )
    }

    func showAlbumSelection() {
        guard allowsAlbum,
              didPrepareSession,
              !captureAttemptState.isActive,
              presentedViewController == nil,
              guideController == nil else { return }
        stopCameraSession()
        cameraController.albumDidOpen()
        let album = AIScanAlbumSelectionViewController(
            allowsPositionSelection: allowsSkinPositionSelection,
            initialPosition: scanContext.analysisPosition
        )
        albumController = album
        isAlbumSelectionPresented = true
        isAlbumTransitioningToProgress = false
        pendingAlbumRestoration = false
        album.onClose = { [weak self, weak album] in
            guard let self, let album, !self.isClosed else { return }
            self.cameraController.albumDidCancel()
            self.isAlbumSelectionPresented = false
            self.isAlbumTransitioningToProgress = false
            self.pendingAlbumRestoration = false
            album.dismiss(animated: true) { [weak self] in
                guard let self, !self.isClosed else { return }
                self.albumController = nil
                self.startCameraSession()
            }
        }
        album.onAnalyze = { [weak self, weak album] image, position in
            guard let self, let album, !self.isClosed else { return }
            guard self.captureAttemptState.begin(at: self.monotonicTime()),
                  self.captureAttemptState.markDiagnosing() else {
                album.setAnalyzing(false)
                return
            }
            self.isDiagnosingAlbum = true
            self.pendingAlbumProgress = nil
            self.capturedPreviewImage = nil
            if let position {
                self.scanContext.analysisPosition = position
                self.scanContext.analysisSubpart = nil
                self.scanContext.displaySubpart = position.uppercased()
            }
            do {
                try self.cameraController.diagnosePhoto(image)
            } catch {
                self.handleAlbumValidationFailure(error)
            }
        }
        present(album, animated: true)
    }

    @_spi(AIScanLifecycle)
    public func resultDidBecomeVisible() {
        cameraController.resultDidBecomeVisible()
    }

    @_spi(AIScanLifecycle)
    public func resultDidShare() {
        cameraController.resultDidShare()
    }

    private func handleAlbumValidationFailure(_ error: Error) {
        guard let albumController else {
            fail(error)
            return
        }
        _ = captureAttemptState.markFailed()
        _ = captureAttemptState.prepareForRetry()
        cameraController.resetCaptureAttempt()
        isDiagnosingAlbum = false
        pendingAlbumProgress = nil
        albumController.setAnalyzing(false)
        albumController.setValidationMessage(AIScanCameraStrings.albumDisplayMessage(
            for: error,
            partType: scanContext.partType,
            analysisPosition: scanContext.analysisPosition
        ))
        restoreAlbumSelectionIfNeeded(albumController)
    }

    private func handleAlbumRetake(_ result: AISCDisplayResult) {
        guard let albumController else { return }
        _ = captureAttemptState.markNeedsRetake()
        _ = captureAttemptState.prepareForRetry()
        cameraController.resetCaptureAttempt()
        isDiagnosingAlbum = false
        pendingAlbumProgress = nil
        albumController.setAnalyzing(false)
        albumController.setValidationMessage(retakeTitle(for: result.retakeReasonCode))
        restoreAlbumSelectionIfNeeded(albumController)
    }

    private func restoreAlbumSelectionIfNeeded(
        _ albumController: AIScanAlbumSelectionViewController
    ) {
        guard !isAlbumSelectionPresented else { return }
        removeQuestionnaire()
        pendingQuestionnaire = nil
        if isAlbumTransitioningToProgress {
            pendingAlbumRestoration = true
            return
        }
        dismissPresentedSurface { [weak self, weak albumController] in
            guard let self,
                  let albumController,
                  !self.isClosed,
                  self.albumController === albumController else { return }
            self.progressController = nil
            self.isAlbumSelectionPresented = true
            self.present(albumController, animated: false)
        }
    }

    func reprepareCurrentSession() {
        didPrepareSession = false
        captureAttemptState.cancel()
        stopCaptureAttemptUI()
        cameraSurface.setPreparing(true)
        stopCameraSession()
        cameraController.reset()
        cameraController.prepare(
            context: scanContext,
            detailedProgress: { [weak self] progress in
                DispatchQueue.main.async { [weak self] in
                    self?.showDownloadProgress(progress)
                }
            }
        ) { [weak self] error in
            let callback = AIScanCameraCallbackValue(error)
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isClosed else { return }
                if let error = callback.value {
                    self.fail(error)
                    return
                }
                do {
                    try self.cameraController.configure()
                } catch {
                    self.fail(error)
                    return
                }
                if self.requestedTorchEnabled {
                    self.isTorchEnabled = false
                    self.setTorch(true)
                } else {
                    self.isTorchEnabled = false
                    self.cameraSurface.setFlashEnabled(false)
                }
                self.finishPreparationFlow()
            }
        }
    }

    private func showProgressIfNeeded() -> TTProgressViewController {
        if let progressController { return progressController }
        let progress = TTProgressViewController.instantiate()
        if let capturedPreviewImage {
            progress.set(previewImage: capturedPreviewImage)
        }
        progressController = progress
        present(progress, animated: false)
        return progress
    }

    private func showQuestionnaire(_ questionnaire: AISCQuestionnaire) {
        guard scanContext.questionnaireEnabled else {
            pendingQuestionnaire = nil
            removeQuestionnaire()
            return
        }
        guard !isClosed, !questionnaire.prompts.isEmpty else { return }
        guard !isAlbumSelectionPresented, !isAlbumTransitioningToProgress else {
            pendingQuestionnaire = questionnaire
            return
        }
        removeQuestionnaire()
        pendingQuestionnaire = nil

        let progress = showProgressIfNeeded()
        progress.loadViewIfNeeded()
        let viewModel = AIScanQuestionnaireViewModel(
            prompts: questionnaire.prompts
        ) { [weak self] answers in
            guard let self, !self.isClosed else { return }
            self.removeQuestionnaire()
            self.cameraController.submitQuestionnaireAnswers(answers)
        }
        let host = UIHostingController(
            rootView: AIScanQuestionnaireView(viewModel: viewModel)
        )
        host.view.accessibilityIdentifier = "aiscan.questionnaire"
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        progress.addChild(host)
        progress.view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: progress.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: progress.view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: progress.view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: progress.view.bottomAnchor),
        ])
        host.didMove(toParent: progress)
        questionnaireController = host
    }

    private func removeQuestionnaire() {
        guard let questionnaireController else { return }
        questionnaireController.willMove(toParent: nil)
        questionnaireController.view.removeFromSuperview()
        questionnaireController.removeFromParent()
        self.questionnaireController = nil
    }

    private func dismissPresentedSurface(completion: @escaping () -> Void) {
        transientSurfaceCoordinator.dismissPresentedSurface(
            from: self,
            animated: false,
            completion: completion
        )
    }

    private func dismissCameraStack(completion: @escaping () -> Void) {
        // UIKit dismisses an animated modal chain one surface at a time. Cross-
        // dissolve the entire window while removing the hierarchy without modal
        // animation so progress and camera leave as one visual transition.
        stackDismisser.dismissStack(
            from: self,
            transition: .coordinatedCrossDissolve(duration: 0.2),
            completion: completion
        )
    }

    /// Closes the default result surface and the camera beneath it as one SDK
    /// flow. The result controller is embedded in a SwiftUI host, so it cannot
    /// safely infer the modal owner from its own `presentingViewController`.
    @_spi(AIScanLifecycle)
    public func dismissCompletedScan(completion: (() -> Void)? = nil) {
        guard !isClosed else {
            completion?()
            return
        }
        isClosed = true
        removeQuestionnaire()
        pendingQuestionnaire = nil
        captureAttemptState.cancel()
        stopCaptureAttemptUI()
        stopCameraSession()
        cameraController.cancel()
        onResult = nil
        dismissCameraStack { [weak self] in
            self?.progressController = nil
            completion?()
        }
    }

    private var automaticGuideDefaultsKey: String {
        let pet = scanContext.petType == .cat ? "cat" : "dog"
        let part: String
        switch scanContext.partType {
        case .eye: part = "eye"
        case .teeth: part = "teeth"
        case .skin: part = scanContext.analysisPosition ?? "skin"
        default: part = "unknown"
        }
        return "com.aiforpet.didShowPreviewGuide.\(pet).\(part)"
    }

    private var shouldShowAutomaticGuide: Bool {
        UserDefaults.standard.object(forKey: automaticGuideDefaultsKey) == nil
    }
}

@MainActor
extension AIScanCameraViewController: AIScanCameraControllerDelegate {
    public func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation) {
        if captureAttemptState.isActive {
            overlayController.apply(evaluation: evaluation)
        } else {
            overlayController.setMessage(AIScanCameraStrings.localized(.startPrompt))
        }
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation) {
        guard captureAttemptState.markDiagnosing() else { return }
        stopCaptureAttemptUI()
        cameraSurface.flashCapture()
        cameraSurface.setPreparing(true)
        stopCameraSession()
        showProgressIfNeeded().set(progress: 0, animated: false)
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didCapturePreview image: UIImage
    ) {
        guard captureAttemptState.phase == .diagnosing else { return }
        capturedPreviewImage = image
        guard albumController != nil, isAlbumSelectionPresented else {
            showProgressIfNeeded().set(previewImage: image)
            return
        }
        isAlbumSelectionPresented = false
        isAlbumTransitioningToProgress = true
        dismissPresentedSurface { [weak self] in
            guard let self, !self.isClosed else { return }
            self.isAlbumTransitioningToProgress = false
            guard let albumController = self.albumController else { return }
            if self.pendingAlbumRestoration {
                self.pendingAlbumRestoration = false
                self.progressController = nil
                self.isAlbumSelectionPresented = true
                self.present(albumController, animated: false)
                return
            }
            guard self.isDiagnosingAlbum,
                  self.captureAttemptState.phase == .diagnosing else { return }
            let progress = self.showProgressIfNeeded()
            progress.set(previewImage: image)
            if let pendingProgress = self.pendingAlbumProgress {
                progress.set(progress: pendingProgress, animated: true)
                self.pendingAlbumProgress = nil
            }
            if let questionnaire = self.pendingQuestionnaire {
                self.showQuestionnaire(questionnaire)
            }
        }
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didUpdateDiagnosisProgress progress: Double) {
        guard captureAttemptState.phase == .diagnosing else { return }
        if albumController != nil, isAlbumSelectionPresented {
            pendingAlbumProgress = progress
            return
        }
        showProgressIfNeeded().set(progress: progress, animated: true)
    }

    public func aiscanCameraController(
        _ controller: AIScanCameraController,
        didRequest questionnaire: AISCQuestionnaire
    ) {
        guard captureAttemptState.phase == .diagnosing else { return }
        showQuestionnaire(questionnaire)
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult) {
        guard !isClosed else { return }
        if result.requiresRetake {
            removeQuestionnaire()
            pendingQuestionnaire = nil
            if isDiagnosingAlbum, albumController != nil {
                handleAlbumRetake(result)
                return
            }
            guard captureAttemptState.markNeedsRetake() else { return }
            stopCameraSession()
            stopCaptureAttemptUI()
            dismissPresentedSurface { [weak self] in
                guard let self, !self.isClosed else { return }
                self.progressController = nil
                self.cameraSurface.setPreparing(false)
                self.startCameraSession()
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.isClosed else { return }
                    self.presentOriginalRetake(reasonCode: result.retakeReasonCode)
                }
            }
            return
        }
        guard captureAttemptState.markCompleted() else { return }
        removeQuestionnaire()
        pendingQuestionnaire = nil
        isDiagnosingAlbum = false
        pendingAlbumProgress = nil
        albumController = nil
        isAlbumSelectionPresented = false
        isAlbumTransitioningToProgress = false
        pendingAlbumRestoration = false
        stopCameraSession()
        showProgressIfNeeded().set(progress: 1, animated: true)
        dismissPresentedSurface { [weak self] in
            guard let self, !self.isClosed else { return }
            self.progressController = nil
            self.onResult?(result)
        }
    }

    public func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error) {
        if isDiagnosingAlbum, albumController != nil {
            handleAlbumValidationFailure(error)
            return
        }
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

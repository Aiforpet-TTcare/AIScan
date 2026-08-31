import AudioToolbox
import UIKit
@preconcurrency import AIScanCore

/// Runtime adapter for the original AIScan 2.2.4 camera storyboard.
///
/// Layout, constraints, colors, images, and controls live exclusively in
/// `TTCamera.storyboard`. This type only forwards storyboard actions to Core.
@MainActor
@objc(CameraViewController)
final class CameraViewController: UIViewController {
    @IBOutlet var pauseIcons: [UIView]?
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var optionActivityIndicator: UIActivityIndicatorView?
    @IBOutlet weak var guideButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var captureButtonContainer: UIView!
    @IBOutlet weak var preview: UIView!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var effectView: UIView!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var debugImageView: UIImageView?
    @IBOutlet weak var pauseIconContainer: UIView?
    @IBOutlet weak var guideContainer: UIStackView!
    @IBOutlet weak var sceneView: UIView!
    @IBOutlet weak var partSelectedBackgroundView: UIView?
    @IBOutlet weak var partSelectedContainer: UIView?

    var onCapture: (() -> Void)?
    var onClose: (() -> Void)?
    var onFlash: ((Bool) -> Void)?
    var onGuide: (() -> Void)?
    var onSelectPart: (() -> Void)?
    var onAlbum: (() -> Void)?
    var onZoom: ((CGFloat) -> Void)?

    private let fanProgressView = TTFanProgressView()
    private var captureAttentionView: UIImageView?
    private var showsPartSelector = false
    private var showsGuideControl = true
    private var showsAlbumControl = false
    private var isPreparing = true
    private var isCaptureDebouncing = false
    private var isFlashAvailable = true
    private var isCaptureAttemptActive = false
    private var idleCaptureImage: UIImage?
    var playSystemSound: (SystemSoundID) -> Void = { AudioServicesPlaySystemSound($0) }
    var generateImpactFeedback: (UIImpactFeedbackGenerator.FeedbackStyle) -> Void = {
        UIImpactFeedbackGenerator(style: $0).impactOccurred()
    }
    var generateNotificationFeedback: (UINotificationFeedbackGenerator.FeedbackType) -> Void = {
        UINotificationFeedbackGenerator().notificationOccurred($0)
    }
    private lazy var recordingCaptureImage = Self.gradientImage(
        size: CGSize(width: 80, height: 80),
        colors: [
            UIColor(red: 248 / 255, green: 122 / 255, blue: 165 / 255, alpha: 1),
            UIColor(red: 247 / 255, green: 111 / 255, blue: 79 / 255, alpha: 1),
            UIColor(red: 248 / 255, green: 212 / 255, blue: 59 / 255, alpha: 1),
        ]
    )
    private(set) lazy var albumButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(bundledImage("album_button_icon"), for: .normal)
        button.accessibilityLabel = AIScanCameraStrings.localizedMessageKey("camera.album")
        button.accessibilityIdentifier = "aiscan.camera.album"
        button.isHidden = true
        button.addTarget(self, action: #selector(didTapAlbumButton), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        previewImageView.isHidden = true
        debugImageView?.isHidden = true
        sceneView.isHidden = true
        effectView.alpha = 0
        pauseIconContainer?.isHidden = true
        pauseIcons?.forEach { $0.layer.cornerRadius = 1.5 }
        optionActivityIndicator?.color = UIColor(
            red: 247 / 255,
            green: 111 / 255,
            blue: 79 / 255,
            alpha: 1
        )
        optionActivityIndicator?.stopAnimating()
        partSelectedBackgroundView?.layer.cornerRadius = 16
        partSelectedBackgroundView?.clipsToBounds = true
        effectView.backgroundColor = .white
        flashButton.setImage(bundledImage("flash_off_circle"), for: .normal)
        flashButton.setImage(bundledImage("flash_on_circle"), for: .selected)
        idleCaptureImage = captureButton.image(for: .normal)
        captureButton.layer.masksToBounds = true
        fanProgressView.frame = captureButtonContainer.bounds
        fanProgressView.setProgress(to: 0)
        fanProgressView.isHidden = true
        fanProgressView.accessibilityIdentifier = "aiscan.camera.capture.fan-progress"
        captureButtonContainer.addSubview(fanProgressView)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        captureButton.accessibilityLabel = AIScanCameraStrings.localized(.capture)
        captureButton.accessibilityIdentifier = "aiscan.camera.capture"
        closeButton.accessibilityLabel = AIScanCameraStrings.localized(.close)
        closeButton.accessibilityIdentifier = "aiscan.camera.close"
        flashButton.accessibilityLabel = AIScanCameraStrings.localizedMessageKey("camera.flash")
        flashButton.accessibilityIdentifier = "aiscan.camera.flash"
        guideButton.accessibilityLabel = AIScanCameraStrings.localized(.guide)
        guideButton.accessibilityIdentifier = "aiscan.camera.guide"
        applyLocalizedCopy()
        partSelectedContainer?.accessibilityIdentifier = "aiscan.camera.skin-part"
        view.addSubview(albumButton)
        NSLayoutConstraint.activate([
            albumButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 44),
            albumButton.centerYAnchor.constraint(equalTo: captureButtonContainer.centerYAnchor),
            albumButton.widthAnchor.constraint(equalToConstant: 44),
            albumButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        captureButton.layer.cornerRadius = captureButton.bounds.width / 2
        captureButtonContainer.layer.cornerRadius = captureButtonContainer.bounds.width / 2
        fanProgressView.frame = captureButtonContainer.bounds
        roundBottomCorners(preview)
        roundBottomCorners(overlayView)
    }

    @IBAction func capture(_ sender: Any) {
        guard captureButton.isEnabled else { return }
        isCaptureDebouncing = true
        updateControlAvailability()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isCaptureDebouncing = false
            self?.updateControlAvailability()
        }
        onCapture?()
    }

    @IBAction func close(_ sender: Any) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onClose?()
    }

    @IBAction func didTapFlashButton(_ sender: UIButton) {
        guard sender.isEnabled else { return }
        sender.isSelected.toggle()
        UISelectionFeedbackGenerator().selectionChanged()
        onFlash?(sender.isSelected)
    }

    @IBAction func guideAction(_ sender: Any) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onGuide?()
    }

    @IBAction func didTapSelectedPartButton(_ sender: Any) {
        onSelectPart?()
    }

    @objc private func didTapAlbumButton() {
        guard albumButton.isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onAlbum?()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }
        onZoom?(gesture.scale)
        gesture.scale = 1
    }

    func setPreparing(_ preparing: Bool) {
        isPreparing = preparing
        updateControlAvailability()
        if preparing {
            optionActivityIndicator?.startAnimating()
        } else {
            optionActivityIndicator?.stopAnimating()
        }
    }

    func setPreparationIndicatorAnimating(_ animating: Bool) {
        if animating {
            optionActivityIndicator?.startAnimating()
        } else {
            optionActivityIndicator?.stopAnimating()
        }
    }

    func configureControls(
        showsPartSelector: Bool,
        showsGuide: Bool,
        showsAlbum: Bool = false
    ) {
        self.showsPartSelector = showsPartSelector
        showsGuideControl = showsGuide
        showsAlbumControl = showsAlbum
        partSelectedContainer?.isHidden = !showsPartSelector
        guideButton.isHidden = !showsGuide
        guideContainer.isHidden = !showsGuide
        albumButton.isHidden = !showsAlbum
    }

    func applyLocalizedCopy(languageCode: String? = nil) {
        let guideTitle = AIScanCameraStrings.localized(.guide, languageCode: languageCode)
        guideContainer.allDescendantLabels.forEach { $0.text = guideTitle }
    }

    func setFlashEnabled(_ enabled: Bool) {
        flashButton.isSelected = enabled
    }

    func setFlashAvailable(_ available: Bool) {
        isFlashAvailable = available
        if !available {
            flashButton.isSelected = false
        }
        updateControlAvailability()
    }

    func startCaptureButtonAttentionAnimation() {
        captureAttentionView?.removeFromSuperview()
        let attentionView = UIImageView(image: recordingCaptureImage)
        attentionView.frame = captureButton.bounds
        attentionView.layer.cornerRadius = captureButton.bounds.width / 2
        attentionView.clipsToBounds = true
        attentionView.alpha = 0
        attentionView.isUserInteractionEnabled = false
        captureButtonContainer.addSubview(attentionView)
        captureAttentionView = attentionView

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0
        opacity.toValue = 1
        opacity.duration = 0.26
        opacity.autoreverses = true
        opacity.repeatCount = 6
        opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak attentionView] in
            attentionView?.removeFromSuperview()
            if self?.captureAttentionView === attentionView {
                self?.captureAttentionView = nil
            }
        }
        attentionView.layer.add(opacity, forKey: "capture-attention")
        CATransaction.commit()
    }

    func stopCaptureButtonAttentionAnimation() {
        captureAttentionView?.layer.removeAnimation(forKey: "capture-attention")
        captureAttentionView?.removeFromSuperview()
        captureAttentionView = nil
    }

    func flashCapture() {
        playSystemSound(1118)
        effectView.alpha = 1
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: { [weak self] in self?.effectView.alpha = 0 },
            completion: { [weak self] _ in
                self?.effectView.alpha = 0
                self?.generateNotificationFeedback(.success)
            }
        )
    }

    func setCaptureAttempt(active: Bool, progress: CGFloat = 0) {
        if active != isCaptureAttemptActive {
            isCaptureAttemptActive = active
            if active {
                playSystemSound(1117)
            }
            generateImpactFeedback(.heavy)
        }
        if active {
            stopCaptureButtonAttentionAnimation()
        }
        fanProgressView.isHidden = !active
        fanProgressView.setProgress(to: active ? progress : 0)
        closeButton.isHidden = active
        flashButton.isHidden = active
        guideButton.isHidden = active || !showsGuideControl
        guideContainer.isHidden = active || !showsGuideControl
        partSelectedContainer?.isHidden = active || !showsPartSelector
        albumButton.isHidden = active || !showsAlbumControl
        pauseIconContainer?.isHidden = true
        captureButton.setImage(active ? recordingCaptureImage : idleCaptureImage, for: .normal)
    }

    private func updateControlAvailability() {
        captureButton.isEnabled = !isPreparing && !isCaptureDebouncing
        flashButton.isEnabled = !isPreparing && isFlashAvailable
        albumButton.isEnabled = !isPreparing
    }

    private func roundBottomCorners(_ target: UIView) {
        let path = UIBezierPath(
            roundedRect: target.bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: 30, height: 30)
        )
        let mask = CAShapeLayer()
        mask.frame = target.bounds
        mask.path = path.cgPath
        target.layer.mask = mask
    }

    private func bundledImage(_ name: String) -> UIImage? {
        UIImage(named: name, in: AIScanCameraResourceBundle.bundle, compatibleWith: nil)
    }

    private static func gradientImage(size: CGSize, colors: [UIColor]) -> UIImage? {
        guard size.width > 0, size.height > 0, !colors.isEmpty else { return nil }
        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.addEllipse(in: CGRect(origin: .zero, size: size))
            context.cgContext.clip()
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors.map(\.cgColor) as CFArray,
                locations: nil
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height / 2),
                end: CGPoint(x: size.width, y: size.height / 2),
                options: []
            )
        }
    }

    static func instantiate(partType: AISCPartType) -> CameraViewController {
        guard let controller = UIStoryboard(
            name: "TTCamera",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: "CameraViewController") as? CameraViewController else {
            preconditionFailure("The original TTCamera storyboard is unavailable.")
        }
        return controller
    }
}

/// Original AIScan 2.2.4 fan-shaped capture progress view.
@MainActor
final class TTFanProgressView: UIView {
    private let progressLayer = CAShapeLayer()

    private(set) var progress: CGFloat = 0
    var renderedStrokeEnd: CGFloat { progressLayer.strokeEnd }

    var progressColor = UIColor(white: 0, alpha: 1) {
        didSet {
            progressLayer.strokeColor = progressColor.cgColor
            progressLayer.strokeEnd = 0
        }
    }

    var lineWidth: CGFloat = 0 {
        didSet { configureLayers() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureLayers()
    }

    private func configureView() {
        layer.addSublayer(progressLayer)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    private func configureLayers() {
        let radius = bounds.width / 4 - 2
        let circularPath = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: 3 * .pi / 2,
            endAngle: -.pi / 2,
            clockwise: false
        )
        progressLayer.path = circularPath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = radius * 2
    }

    func setProgress(to progress: CGFloat) {
        self.progress = min(max(progress, 0), 1)
        progressLayer.strokeEnd = 1 - self.progress
    }
}

@MainActor
class TTOverlayViewController: UIViewController {
    @IBOutlet weak var focusContainer: UIView?
    @IBOutlet weak var focusImageView: UIImageView?
    @IBOutlet weak var messageContainer: UIView!
    @IBOutlet weak var messageLabel: UILabel!

    private var roundedFocusMaskView: CameraRoundedFocusMaskView?
    private var currentMessage: String?
    private static let messageTransitionKey = "aiscan.guidance.crossfade"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        messageLabel.text = nil
        messageLabel.isHidden = false
        messageLabel.alpha = 0
        messageContainer.isHidden = false
        installOriginalRoundedFocusMaskIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let focusContainer, let roundedFocusMaskView else { return }
        roundedFocusMaskView.holeSize = focusContainer.bounds.size
        roundedFocusMaskView.holeCenter = roundedFocusMaskView.convert(
            focusContainer.center,
            from: focusContainer.superview
        )
        roundedFocusMaskView.setNeedsLayout()
        roundedFocusMaskView.layoutIfNeeded()
    }

    func apply(evaluation: AISCFrameEvaluation) {
        setMessage(Self.guidanceMessage(for: evaluation))
    }

    func setMessage(_ message: String?, animated: Bool = true) {
        guard message != currentMessage else { return }
        currentMessage = message
        messageContainer.isHidden = false
        messageLabel.isHidden = false
        messageLabel.layer.removeAnimation(forKey: Self.messageTransitionKey)
        if animated {
            messageLabel.layer.add(
                Self.makeMessageTransition(),
                forKey: Self.messageTransitionKey
            )
        }
        messageLabel.text = message
        messageLabel.alpha = message == nil ? 0 : 1
    }

    static func makeMessageTransition() -> CATransition {
        let transition = CATransition()
        transition.duration = 0.16
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .fade
        return transition
    }

    func setCameraActive(_ active: Bool, animated: Bool = true) {
        view.layer.removeAllAnimations()
        if active {
            view.backgroundColor = .black
        }
        let update: () -> Void = { [weak self] in
            self?.view.backgroundColor = active ? .clear : .black
        }
        guard animated else {
            update()
            return
        }
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: update
        )
    }

    private func installOriginalRoundedFocusMaskIfNeeded() {
        guard focusContainer != nil else { return }
        let focusMask = CameraRoundedFocusMaskView()
        focusMask.accessibilityIdentifier = "aiscan.camera.rounded-focus-mask"
        focusMask.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(focusMask, at: 0)
        NSLayoutConstraint.activate([
            focusMask.topAnchor.constraint(equalTo: view.topAnchor),
            focusMask.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            focusMask.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            focusMask.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 20),
        ])
        view.clipsToBounds = true
        roundedFocusMaskView = focusMask
    }

    private static func guidanceMessage(for evaluation: AISCFrameEvaluation) -> String? {
        let key: String
        switch evaluation.guidanceCode {
        case .moveCloser:
            key = "move_closer"
        case .moveFarther:
            key = "move_farther"
        case .holdStill:
            key = "hold_still"
        case .adjustAngle:
            key = "adjust_angle"
        case .improveLighting:
            key = "improve_lighting"
        default:
            return nil
        }
        return AIScanCameraStrings.localizedMessageKey(key)
    }

    static func instantiate(partType: AISCPartType) -> TTOverlayViewController {
        let identifier: String
        switch partType {
        case .eye:
            identifier = "TTOverlayEyeViewController"
        case .teeth:
            identifier = "TTOverlayToothViewController"
        case .skin:
            identifier = "TTOverlaySkinViewController"
        default:
            identifier = "TTOverlaySkinViewController"
        }
        guard let controller = UIStoryboard(
            name: "TTCamera",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: identifier) as? TTOverlayViewController else {
            preconditionFailure("The original TTCamera overlay is unavailable.")
        }
        return controller
    }
}

@MainActor @objc(TTOverlayEyeViewController)
final class TTOverlayEyeViewController: TTOverlayViewController {
    @IBOutlet weak var focusEyeIcon: UIImageView?
}

@MainActor @objc(TTOverlaySkinViewController)
final class TTOverlaySkinViewController: TTOverlayViewController {}

@MainActor @objc(TTOverlayToothViewController)
final class TTOverlayToothViewController: TTOverlayViewController {}

/// Runtime adapter for the original preview-guide scene in TTCamera.
@MainActor
@objc(PreviewGuideViewController)
final class PreviewGuideViewController: UIViewController {
    @IBOutlet weak var guideImageView: UIImageView!
    @IBOutlet weak var focusImageView: UIImageView?
    @IBOutlet weak var focusContainer: UIView?
    @IBOutlet weak var messageContainer: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var focusEyeIcon: UIImageView?
    @IBOutlet weak var centerYLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var widthLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var heightLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var exampleContainer: UIView?
    @IBOutlet weak var exampleView: UIView?

    var onDismiss: (() -> Void)?
    private var guideLottie: AIScanGuideLottie?
    private var lottiePlayer: AIScanLottiePlayerController?
    private var didFinish = false
    private let holeView = CameraRoundedFocusMaskView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "aiscan.camera.guide-preview"
        exampleView?.layer.cornerRadius = 15
        exampleView?.clipsToBounds = true
        messageLabel.text = AIScanCameraStrings.localized(.startPrompt)
        applyLocalizedCopy()
        exampleView?.isHidden = true
        // The original 2.2.4 guide starts with this storyboard-only eye icon
        // hidden. Eye guidance is rendered by its own Lottie; keeping the
        // outlet visible leaks an eye mark into skin and tooth guides for one
        // frame before their media is installed.
        focusEyeIcon?.isHidden = true
        installOriginalGuideMedia()
        holeView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(holeView, at: 1)
        NSLayoutConstraint.activate([
            holeView.topAnchor.constraint(equalTo: view.topAnchor),
            holeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            holeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            holeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didFinish else { return }
        configureHole()
        exampleView?.isHidden = false
        lottiePlayer?.playAnimation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        lottiePlayer?.stopAnimation()
    }

    @IBAction func tap(_ sender: Any) {
        finishGuide()
    }

    func dismissGuide() {
        finishGuide()
    }

    private func configureHole() {
        guard let focusContainer else { return }
        view.layoutIfNeeded()
        holeView.holeSize = focusContainer.bounds.size
        holeView.holeCenter = view.convert(focusContainer.center, from: focusContainer.superview)
    }

    private func finishGuide() {
        guard !didFinish else { return }
        didFinish = true
        lottiePlayer?.stopAnimation()
        onDismiss?()
    }

    private func installOriginalGuideMedia() {
        guard let guideLottie else { return }
        let player = AIScanLottiePlayerController.instance(lottie: guideLottie) { [weak self] in
            self?.finishGuide()
        }
        install(player)
        lottiePlayer = player
    }

    private func install(_ controller: UIViewController) {
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(controller.view, at: 0)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        controller.didMove(toParent: self)
    }

    func applyLocalizedCopy(languageCode: String? = nil) {
        for label in view.allDescendantLabels {
            switch label.text {
            case "잘 보고 따라해주세요", "Follow our demo tutorial", "よく見て従ってください":
                label.text = AIScanCameraStrings.localizedMessageKey(
                    "camera.guide.follow",
                    languageCode: languageCode
                )
            case "촬영 예시 화면입니다.", "Example capture screen.", "撮影例です。":
                label.text = AIScanCameraStrings.localizedMessageKey(
                    "camera.guide.example",
                    languageCode: languageCode
                )
            default:
                break
            }
        }
    }

    static func instantiate(context: AISCScanContext) -> PreviewGuideViewController {
        guard let controller = UIStoryboard(
            name: "TTCamera",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: "PreviewGuideViewController") as? PreviewGuideViewController else {
            preconditionFailure("The original TTCamera guide scene is unavailable.")
        }
        controller.guideLottie = AIScanGuideLottie(context: context)
        return controller
    }
}

private extension UIView {
    var allDescendantLabels: [UILabel] {
        subviews.reduce(into: self is UILabel ? [self as! UILabel] : []) { labels, child in
            labels.append(contentsOf: child.allDescendantLabels)
        }
    }
}

@MainActor
private final class CameraRoundedFocusMaskView: UIView {
    var holeSize: CGSize? { didSet { setNeedsLayout() } }
    var holeCenter: CGPoint? { didSet { setNeedsLayout() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(rect: bounds)
        let size = holeSize ?? CGSize(width: 200, height: 200)
        let center = holeCenter ?? CGPoint(x: bounds.midX, y: bounds.midY)
        path.append(UIBezierPath(
            roundedRect: CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            cornerRadius: 30
        ))
        path.usesEvenOddFillRule = true
        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.path = path.cgPath
        mask.fillRule = .evenOdd
        layer.mask = mask
    }
}

enum AIScanCameraResourceBundle {
    static let bundle: Bundle = {
#if SWIFT_PACKAGE
        Bundle.module
#else
        let containingBundle = Bundle(for: CameraViewController.self)
        for name in [
            "AIScanReferenceUIResources",
            "AIScanCameraUIResources",
            "AIScan_AIScanCameraUI",
        ] {
            if let url = containingBundle.url(forResource: name, withExtension: "bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return containingBundle
#endif
    }()
}

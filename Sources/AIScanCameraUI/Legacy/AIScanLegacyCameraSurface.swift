import ARKit
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
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var partSelectedBackgroundView: UIView?
    @IBOutlet weak var partSelectedContainer: UIView?

    var onCapture: (() -> Void)?
    var onClose: (() -> Void)?
    var onFlash: ((Bool) -> Void)?
    var onGuide: (() -> Void)?
    var onSelectPart: (() -> Void)?
    var onZoom: ((CGFloat) -> Void)?

    private let captureProgressLayer = CAShapeLayer()
    private var captureAttentionView: UIImageView?
    private var showsPartSelector = false
    private var showsGuideControl = true
    private var idleCaptureImage: UIImage?
    private lazy var recordingCaptureImage = Self.gradientImage(
        size: CGSize(width: 74, height: 74),
        colors: [
            UIColor(red: 248 / 255, green: 122 / 255, blue: 165 / 255, alpha: 1),
            UIColor(red: 247 / 255, green: 111 / 255, blue: 79 / 255, alpha: 1),
            UIColor(red: 248 / 255, green: 212 / 255, blue: 59 / 255, alpha: 1),
        ]
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        previewImageView.isHidden = true
        debugImageView?.isHidden = true
        sceneView.isHidden = true
        effectView.alpha = 0
        pauseIconContainer?.isHidden = true
        optionActivityIndicator?.stopAnimating()
        partSelectedBackgroundView?.layer.cornerRadius = 16
        partSelectedBackgroundView?.clipsToBounds = true
        effectView.backgroundColor = .white
        flashButton.setImage(bundledImage("flash_off_circle"), for: .normal)
        flashButton.setImage(bundledImage("flash_on_circle"), for: .selected)
        idleCaptureImage = captureButton.image(for: .normal)
        captureProgressLayer.fillColor = UIColor.clear.cgColor
        captureProgressLayer.strokeColor = UIColor(
            red: 248 / 255,
            green: 122 / 255,
            blue: 165 / 255,
            alpha: 1
        ).cgColor
        captureProgressLayer.lineWidth = 5
        captureProgressLayer.lineCap = .round
        captureProgressLayer.strokeEnd = 0
        captureProgressLayer.isHidden = true
        captureButtonContainer.layer.addSublayer(captureProgressLayer)
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
        partSelectedContainer?.accessibilityIdentifier = "aiscan.camera.skin-part"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        captureButton.layer.cornerRadius = captureButton.bounds.width / 2
        captureButtonContainer.layer.cornerRadius = captureButtonContainer.bounds.width / 2
        let inset = captureProgressLayer.lineWidth / 2
        captureProgressLayer.frame = captureButtonContainer.bounds
        captureProgressLayer.path = UIBezierPath(
            ovalIn: captureButtonContainer.bounds.insetBy(dx: inset, dy: inset)
        ).cgPath
        roundBottomCorners(preview)
        roundBottomCorners(overlayView)
    }

    @IBAction func capture(_ sender: Any) {
        captureButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.captureButton.isEnabled = true
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        onCapture?()
    }

    @IBAction func close(_ sender: Any) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onClose?()
    }

    @IBAction func didTapFlashButton(_ sender: UIButton) {
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

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }
        onZoom?(gesture.scale)
        gesture.scale = 1
    }

    func setPreparing(_ preparing: Bool) {
        captureButton.isEnabled = !preparing
        if preparing {
            optionActivityIndicator?.startAnimating()
        } else {
            optionActivityIndicator?.stopAnimating()
        }
    }

    func configureControls(showsPartSelector: Bool, showsGuide: Bool) {
        self.showsPartSelector = showsPartSelector
        showsGuideControl = showsGuide
        partSelectedContainer?.isHidden = !showsPartSelector
        guideButton.isHidden = !showsGuide
        guideContainer.isHidden = !showsGuide
    }

    func setFlashEnabled(_ enabled: Bool) {
        flashButton.isSelected = enabled
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
        effectView.alpha = 1
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: { [weak self] in self?.effectView.alpha = 0 },
            completion: nil
        )
    }

    func setCaptureAttempt(active: Bool, progress: CGFloat = 0) {
        if active {
            stopCaptureButtonAttentionAnimation()
        }
        captureProgressLayer.isHidden = !active
        captureProgressLayer.strokeEnd = min(max(progress, 0), 1)
        closeButton.isHidden = active
        flashButton.isHidden = active
        guideButton.isHidden = active || !showsGuideControl
        guideContainer.isHidden = active || !showsGuideControl
        partSelectedContainer?.isHidden = active || !showsPartSelector
        pauseIconContainer?.isHidden = true
        captureButton.setImage(active ? recordingCaptureImage : idleCaptureImage, for: .normal)
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
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors.map(\.cgColor) as CFArray,
                locations: nil
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    static func instantiate(partType: AISCPartType) -> CameraViewController {
        let identifier = partType == .joint
            ? "CameraJointViewController"
            : "CameraViewController"
        guard let controller = UIStoryboard(
            name: "TTCamera",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: identifier) as? CameraViewController else {
            preconditionFailure("The original TTCamera storyboard is unavailable.")
        }
        return controller
    }
}

@MainActor
class TTOverlayViewController: UIViewController {
    @IBOutlet weak var focusContainer: UIView?
    @IBOutlet weak var focusImageView: UIImageView?
    @IBOutlet weak var messageContainer: UIView!
    @IBOutlet weak var messageLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        messageLabel.text = AIScanCameraStrings.localized(.scanning)
    }

    func apply(evaluation: AISCFrameEvaluation) {
        let message = evaluation.displayMessageKey.flatMap { key in
            NSLocalizedString(
                key,
                tableName: "Localizable",
                bundle: AIScanCameraResourceBundle.bundle,
                value: key,
                comment: ""
            )
        }
        messageLabel.text = message ?? (evaluation.captureAllowed
            ? AIScanCameraStrings.localized(.ready)
            : AIScanCameraStrings.localized(.scanning))
        focusImageView?.alpha = evaluation.captureAllowed ? 1 : 0.72
    }

    func setMessage(_ message: String) {
        messageLabel.text = message
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
        case .joint:
            identifier = "TTOverlayJointViewController"
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

@MainActor @objc(TTOverlayJointViewController)
final class TTOverlayJointViewController: TTOverlayViewController {
    @IBOutlet weak var guideContainer: UIView?
}

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
    private var guideImages: [UIImage] = []
    private var guideIndex = 0
    private var isAnimating = false
    private let dotAnimationView = CameraGuideDotAnimationView()
    private let holeView = CameraGuideHoleView()
    private var automaticDismissWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        exampleView?.layer.cornerRadius = 15
        exampleView?.clipsToBounds = true
        messageLabel.text = AIScanCameraStrings.localized(.startPrompt)
        setLocalizedExampleText(in: view)
        exampleView?.isHidden = true
        focusEyeIcon?.isHidden = false
        guideImageView.image = guideImages.first
        holeView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(holeView, at: 1)
        NSLayoutConstraint.activate([
            holeView.topAnchor.constraint(equalTo: view.topAnchor),
            holeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            holeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            holeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        dotAnimationView.translatesAutoresizingMaskIntoConstraints = false
        focusContainer?.addSubview(dotAnimationView)
        if let focusContainer {
            NSLayoutConstraint.activate([
                dotAnimationView.topAnchor.constraint(equalTo: focusContainer.topAnchor),
                dotAnimationView.leadingAnchor.constraint(equalTo: focusContainer.leadingAnchor),
                dotAnimationView.trailingAnchor.constraint(equalTo: focusContainer.trailingAnchor),
                dotAnimationView.bottomAnchor.constraint(equalTo: focusContainer.bottomAnchor),
            ])
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isAnimating = true
        configureHole()
        exampleView?.isHidden = false
        animateNextGuideImage()
        let workItem = DispatchWorkItem { [weak self] in self?.finishGuide() }
        automaticDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: workItem)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isAnimating = false
        automaticDismissWorkItem?.cancel()
        guideImageView.layer.removeAllAnimations()
        dotAnimationView.stopAnimations()
    }

    @IBAction func tap(_ sender: Any) {
        finishGuide()
    }

    private func animateNextGuideImage() {
        guard isAnimating, guideImages.count > 1 else { return }
        guideImageView.transform = .identity
        guideImageView.alpha = 1
        focusEyeIcon?.alpha = 1
        dotAnimationView.alpha = 0
        UIView.animateKeyframes(
            withDuration: 5,
            delay: 0,
            options: [.calculationModeCubic, .allowUserInteraction],
            animations: { [weak self] in
                guard let self else { return }
                UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.05) {
                    let scale = CGAffineTransform(scaleX: 1.16, y: 1.16)
                    let shift = CGAffineTransform(
                        translationX: 0,
                        y: self.guideImageView.frame.height * 0.04
                    )
                    self.guideImageView.transform = scale.concatenating(shift)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.15, relativeDuration: 0.05) {
                    self.focusEyeIcon?.alpha = 0
                }
                UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0) {
                    self.dotAnimationView.alpha = 1
                    self.dotAnimationView.startAnimations()
                }
                UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.1) {
                    self.dotAnimationView.alpha = 0
                }
                UIView.addKeyframe(withRelativeStartTime: 0.9, relativeDuration: 0.05) {
                    self.guideImageView.alpha = 0
                }
                UIView.addKeyframe(withRelativeStartTime: 0.95, relativeDuration: 0.05) {
                    self.guideIndex = (self.guideIndex + 1) % self.guideImages.count
                    self.guideImageView.image = self.guideImages[self.guideIndex]
                    self.guideImageView.alpha = 1
                }
            },
            completion: { [weak self] _ in
                Task { @MainActor [weak self] in self?.animateNextGuideImage() }
            }
        )
    }

    private func configureHole() {
        guard let focusContainer else { return }
        view.layoutIfNeeded()
        holeView.holeSize = focusContainer.bounds.size
        holeView.holeCenter = view.convert(focusContainer.center, from: focusContainer.superview)
    }

    private func finishGuide() {
        guard isAnimating else { return }
        isAnimating = false
        automaticDismissWorkItem?.cancel()
        guideImageView.layer.removeAllAnimations()
        dotAnimationView.stopAnimations()
        onDismiss?()
    }

    private func setLocalizedExampleText(in root: UIView) {
        for label in root.allDescendantLabels
            where label.text == "촬영 예시 화면입니다." || label.text == "Example capture screen." {
            label.text = AIScanCameraStrings.localizedMessageKey("camera.guide.example")
        }
    }

    static func instantiate(context: AISCScanContext) -> PreviewGuideViewController {
        let identifier = context.partType == .joint
            ? "PreviewJointGuideViewController"
            : "PreviewGuideViewController"
        guard let controller = UIStoryboard(
            name: "TTCamera",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: identifier) as? PreviewGuideViewController else {
            preconditionFailure("The original TTCamera guide scene is unavailable.")
        }
        let prefix: String
        switch (context.petType, context.partType, context.analysisPosition) {
        case (.cat, .eye, _): prefix = "cat_eye"
        case (.cat, .teeth, _): prefix = "cat_teeth"
        case (_, .eye, _): prefix = "dog_eye"
        case (_, .teeth, _): prefix = "dog_teeth"
        case (_, .skin, "ear"): prefix = "dog_ear"
        case (_, .skin, "foot"): prefix = "dog_paw"
        default: prefix = "dog_body"
        }
        controller.guideImages = [1, 2].compactMap {
            UIImage(named: "\(prefix)\($0)", in: AIScanCameraResourceBundle.bundle, compatibleWith: nil)
        }
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
private final class CameraGuideDotAnimationView: UIView {
    private var initialized = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !initialized, !bounds.isEmpty else { return }
        initialized = true
        let oval = bounds.insetBy(dx: bounds.width * 0.1, dy: bounds.height * 0.25)
        for _ in 0..<20 {
            let dot = CAShapeLayer()
            dot.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 5, height: 5)).cgPath
            dot.fillColor = UIColor.white.cgColor
            dot.frame = CGRect(
                x: CGFloat.random(in: oval.minX...oval.maxX),
                y: CGFloat.random(in: oval.minY...oval.maxY),
                width: 5,
                height: 5
            )
            dot.opacity = 0
            layer.addSublayer(dot)
        }
    }

    func startAnimations() {
        layer.sublayers?.forEach { dot in
            guard dot.animation(forKey: "startEndFade") == nil else { return }
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [0, 1, 1, 0]
            animation.keyTimes = [0, 0.2, 0.7, 1]
            animation.duration = Double.random(in: 2...4)
            animation.repeatCount = .infinity
            dot.add(animation, forKey: "startEndFade")
        }
    }

    func stopAnimations() {
        layer.sublayers?.forEach { $0.removeAnimation(forKey: "startEndFade") }
    }
}

@MainActor
private final class CameraGuideHoleView: UIView {
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

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

    override func viewDidLoad() {
        super.viewDidLoad()
        previewImageView.isHidden = true
        debugImageView?.isHidden = true
        sceneView.isHidden = true
        effectView.alpha = 0
        pauseIconContainer?.isHidden = true
        optionActivityIndicator?.stopAnimating()
        captureButton.accessibilityLabel = AIScanCameraStrings.localized(.capture)
        captureButton.accessibilityIdentifier = "aiscan.camera.capture"
        closeButton.accessibilityLabel = AIScanCameraStrings.localized(.close)
        closeButton.accessibilityIdentifier = "aiscan.camera.close"
    }

    @IBAction func capture(_ sender: Any) {
        onCapture?()
    }

    @IBAction func close(_ sender: Any) {
        onClose?()
    }

    @IBAction func didTapFlashButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        onFlash?(sender.isSelected)
    }

    @IBAction func guideAction(_ sender: Any) {
        onGuide?()
    }

    @IBAction func didTapSelectedPartButton(_ sender: Any) {
        onSelectPart?()
    }

    func setPreparing(_ preparing: Bool) {
        captureButton.isEnabled = !preparing
        if preparing {
            optionActivityIndicator?.startAnimating()
        } else {
            optionActivityIndicator?.stopAnimating()
        }
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

    override func viewDidLoad() {
        super.viewDidLoad()
        exampleView?.layer.cornerRadius = 15
        exampleView?.clipsToBounds = true
        exampleView?.isHidden = false
        focusEyeIcon?.isHidden = false
        guideImageView.image = guideImages.first
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isAnimating = true
        animateNextGuideImage()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isAnimating = false
        guideImageView.layer.removeAllAnimations()
    }

    @IBAction func tap(_ sender: Any) {
        isAnimating = false
        onDismiss?()
    }

    private func animateNextGuideImage() {
        guard isAnimating, guideImages.count > 1 else { return }
        UIView.transition(
            with: guideImageView,
            duration: 0.5,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: { [weak self] in
                guard let self else { return }
                self.guideIndex = (self.guideIndex + 1) % self.guideImages.count
                self.guideImageView.image = self.guideImages[self.guideIndex]
            },
            completion: { [weak self] _ in
                guard let self, self.isAnimating else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
                    self?.animateNextGuideImage()
                }
            }
        )
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

enum AIScanCameraResourceBundle {
    static let bundle: Bundle = {
#if SWIFT_PACKAGE
        Bundle.module
#else
        let containingBundle = Bundle(for: CameraViewController.self)
        for name in ["AIScanCameraUIResources", "AIScan_AIScanCameraUI"] {
            if let url = containingBundle.url(forResource: name, withExtension: "bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return containingBundle
#endif
    }()
}

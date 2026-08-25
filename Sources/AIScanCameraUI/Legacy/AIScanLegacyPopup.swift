import UIKit

/// Action adapter for the unchanged original TTPopup alert scene.
@MainActor
@objc(TTPopupAlertViewController)
final class TTPopupAlertViewController: UIViewController {
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var iconContainer: UIView!

    private var configuredTitle: String?
    private var primaryTitle: String?
    private var secondaryTitle: String?
    private var primaryAccessibilityIdentifier: String?
    private var onPrimary: (() -> Void)?
    private var onSecondary: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = configuredTitle
        subtitleLabel.isHidden = true
        iconContainer.isHidden = true
        view.accessibilityIdentifier = "aiscan.camera.popup"
        confirmButton.setTitle(primaryTitle, for: .normal)
        confirmButton.accessibilityIdentifier = primaryAccessibilityIdentifier
            ?? (secondaryTitle == nil ? "aiscan.camera.close" : "aiscan.camera.retry")
        confirmButton.layer.cornerRadius = 10
        confirmButton.clipsToBounds = true
        cancelButton.setTitle(secondaryTitle, for: .normal)
        cancelButton.accessibilityIdentifier = "aiscan.camera.close"
        cancelButton.isHidden = secondaryTitle == nil
        view.layer.cornerRadius = 33
        view.clipsToBounds = true
    }

    @IBAction func confirm(_ sender: Any) {
        dismiss(animated: true) { [onPrimary] in onPrimary?() }
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true) { [onSecondary] in onSecondary?() }
    }

    static func instantiate(
        title: String,
        primaryTitle: String,
        secondaryTitle: String?,
        primaryAccessibilityIdentifier: String? = nil,
        onPrimary: (() -> Void)?,
        onSecondary: (() -> Void)?
    ) -> TTPopupAlertViewController {
        guard let controller = UIStoryboard(
            name: "TTPopup",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: "TTPopupAlertViewController") as? TTPopupAlertViewController else {
            preconditionFailure("The original TTPopup alert scene is unavailable.")
        }
        controller.configuredTitle = title
        controller.primaryTitle = primaryTitle
        controller.secondaryTitle = secondaryTitle
        controller.primaryAccessibilityIdentifier = primaryAccessibilityIdentifier
        controller.onPrimary = onPrimary
        controller.onSecondary = onSecondary
        return controller
    }
}

/// Original popup-manager geometry around the original storyboard card.
@MainActor
final class AIScanLegacyPopupContainer: UIViewController {
    private let content: UIViewController
    private let cardWidth: CGFloat

    init(content: UIViewController, cardWidth: CGFloat = 315) {
        self.content = content
        self.cardWidth = cardWidth
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            content.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            content.view.widthAnchor.constraint(equalToConstant: cardWidth),
        ])
        content.didMove(toParent: self)
    }
}

@MainActor
@objc(TTPopupSelectedSkinViewController)
final class TTPopupSelectedSkinViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var earTitleLabel: UILabel!
    @IBOutlet weak var earSubtitleLabel: UILabel!
    @IBOutlet weak var earIcon: UIImageView!
    @IBOutlet weak var earContainer: UIView!
    @IBOutlet weak var earCheckCircle: UIImageView!
    @IBOutlet weak var bodyTitleLabel: UILabel!
    @IBOutlet weak var bodySubtitleLabel: UILabel!
    @IBOutlet weak var bodyIcon: UIImageView!
    @IBOutlet weak var bodyContainer: UIView!
    @IBOutlet weak var bodyCheckCircle: UIImageView!
    @IBOutlet weak var footTitleLabel: UILabel!
    @IBOutlet weak var footSubtitleLabel: UILabel!
    @IBOutlet weak var footIcon: UIImageView!
    @IBOutlet weak var footContainer: UIView!
    @IBOutlet weak var footCheckCircle: UIImageView!
    @IBOutlet weak var flashDescriptionLabel: UILabel!
    @IBOutlet weak var flashSwichImageView: UIImageView!
    @IBOutlet weak var flashContainer: UIView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var flashButton: UIButton!

    var onStart: ((String, Bool) -> Void)?
    var onClose: (() -> Void)?
    private var selectedPosition: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        [earContainer, bodyContainer, footContainer, flashContainer].forEach {
            $0?.layer.cornerRadius = 17
            $0?.clipsToBounds = true
        }
        startButton.layer.cornerRadius = 10
        startButton.clipsToBounds = true
        startButton.isEnabled = false
        flashButton.isSelected = false
        applySelection()
    }

    @IBAction func close(_ sender: Any) {
        dismiss(animated: true) { [onClose] in onClose?() }
    }

    @IBAction func start(_ sender: Any) {
        guard let selectedPosition else { return }
        let flash = flashButton.isSelected
        dismiss(animated: true) { [onStart] in onStart?(selectedPosition, flash) }
    }

    @IBAction func earAction(_ sender: Any) { select("ear") }
    @IBAction func bodyAction(_ sender: Any) { select("belly") }
    @IBAction func footAction(_ sender: Any) { select("foot") }

    @IBAction func flashSwitchAction(_ sender: Any) {
        flashButton.isSelected.toggle()
        flashSwichImageView.image = bundledImage(flashButton.isSelected ? "toggle_On" : "toggle_Off")
    }

    private func select(_ position: String) {
        selectedPosition = position
        startButton.isEnabled = true
        applySelection()
    }

    private func applySelection() {
        let selections = [
            ("ear", earContainer, earCheckCircle),
            ("belly", bodyContainer, bodyCheckCircle),
            ("foot", footContainer, footCheckCircle),
        ]
        selections.forEach { position, container, check in
            let selected = selectedPosition == position
            container?.layer.borderWidth = selected ? 1 : 0
            container?.layer.borderColor = UIColor.separator.cgColor
            check?.image = bundledImage(selected ? "circleFillCheckOn" : "circleFillCheckOff")
        }
    }

    private func bundledImage(_ name: String) -> UIImage? {
        UIImage(named: name, in: AIScanCameraResourceBundle.bundle, compatibleWith: nil)
    }

    static func instantiate(
        onStart: @escaping (String, Bool) -> Void,
        onClose: @escaping () -> Void
    ) -> TTPopupSelectedSkinViewController {
        guard let controller = UIStoryboard(
            name: "TTPopup",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: "TTPopupSelectedSkinViewController") as? TTPopupSelectedSkinViewController else {
            preconditionFailure("The original skin-selection popup is unavailable.")
        }
        controller.onStart = onStart
        controller.onClose = onClose
        return controller
    }
}

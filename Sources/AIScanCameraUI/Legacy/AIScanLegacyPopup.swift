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
    private var configuredSubtitle: String?
    private var primaryTitle: String?
    private var secondaryTitle: String?
    private var primaryAccessibilityIdentifier: String?
    private var onPrimary: (() -> Void)?
    private var onSecondary: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.attributedText = configuredTitle.map {
            AIScanLegacyText.attributed(
                $0,
                font: .systemFont(ofSize: 19, weight: .bold),
                color: titleLabel.textColor,
                alignment: .center
            )
        }
        subtitleLabel.attributedText = configuredSubtitle.map {
            AIScanLegacyText.attributed(
                $0,
                font: .systemFont(ofSize: 14),
                color: subtitleLabel.textColor,
                lineSpacing: 5,
                alignment: .center
            )
        }
        subtitleLabel.isHidden = configuredSubtitle == nil
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
        subtitle: String? = nil,
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
        controller.configuredSubtitle = subtitle
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
    private let cardHeight: CGFloat?

    init(content: UIViewController, cardWidth: CGFloat = 315, cardHeight: CGFloat? = nil) {
        self.content = content
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var shouldAutorotate: Bool { false }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        var constraints = [
            content.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            content.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            content.view.widthAnchor.constraint(equalToConstant: cardWidth),
        ]
        if let cardHeight {
            constraints.append(content.view.heightAnchor.constraint(equalToConstant: cardHeight))
        }
        NSLayoutConstraint.activate(constraints)
        content.didMove(toParent: self)
    }
}

@MainActor
@objc(TTFlashWarningAlertViewController)
final class TTFlashWarningAlertViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var skinContainer: UIView!
    @IBOutlet weak var flashContainer: UIView!
    @IBOutlet weak var flashWarningLabel: UILabel!
    @IBOutlet weak var skinWarningLabel: UILabel!
    @IBOutlet weak var flashButton: UIButton!

    private var showsSkinGuidance = false
    private var startsWithFlash = false
    private var onStart: ((Bool) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashTitle),
            font: .systemFont(ofSize: 18, weight: .bold),
            color: titleLabel.textColor,
            alignment: .center
        )
        subtitleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashSubtitle),
            font: .systemFont(ofSize: 11),
            color: subtitleLabel.textColor,
            lineSpacing: 5,
            alignment: .left
        )
        flashWarningLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashBenefit),
            font: .systemFont(ofSize: 13),
            color: flashWarningLabel.textColor,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.flash.highlight"):
                    (.systemFont(ofSize: 13, weight: .semibold), AIScanLegacyText.accent)
            ]
        )
        skinWarningLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.skinDistance),
            font: .systemFont(ofSize: 12),
            color: skinWarningLabel.textColor,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.skin.warning_highlight"):
                    (.systemFont(ofSize: 12, weight: .bold), AIScanLegacyText.warning)
            ]
        )
        confirmButton.setTitle(AIScanCameraStrings.localized(.start), for: .normal)
        confirmButton.layer.cornerRadius = 10
        confirmButton.clipsToBounds = true
        flashContainer.layer.cornerRadius = 17
        flashContainer.clipsToBounds = true
        flashContainer.layer.borderWidth = 1
        flashContainer.layer.borderColor = UIColor.separator.cgColor
        skinContainer.isHidden = !showsSkinGuidance
        flashButton.isSelected = startsWithFlash
        updateFlashImage()
        view.accessibilityIdentifier = "aiscan.camera.flash-warning"
        confirmButton.accessibilityIdentifier = "aiscan.camera.flash-warning.start"
        flashButton.accessibilityIdentifier = "aiscan.camera.flash-warning.toggle"
    }

    @IBAction func confirm(_ sender: Any) {
        dismiss(animated: true) { [onStart, flashButton] in
            onStart?(flashButton?.isSelected == true)
        }
    }

    @IBAction func didTapFlashButton(_ sender: Any) {
        flashButton.isSelected.toggle()
        updateFlashImage()
    }

    private func updateFlashImage() {
        let name = flashButton.isSelected ? "toggle_On" : "toggle_Off"
        flashButton.setImage(
            UIImage(named: name, in: AIScanCameraResourceBundle.bundle, compatibleWith: nil),
            for: .normal
        )
    }

    static func instantiate(
        showsSkinGuidance: Bool,
        startsWithFlash: Bool,
        onStart: @escaping (Bool) -> Void
    ) -> TTFlashWarningAlertViewController {
        guard let controller = UIStoryboard(
            name: "TTPopup",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(
            withIdentifier: "TTFlashWarningAlertViewController"
        ) as? TTFlashWarningAlertViewController else {
            preconditionFailure("The original flash warning popup is unavailable.")
        }
        controller.showsSkinGuidance = showsSkinGuidance
        controller.startsWithFlash = startsWithFlash
        controller.onStart = onStart
        return controller
    }
}

@MainActor
@objc(TTPopupTimeoverViewController)
final class TTPopupTimeoverViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var guideLabel: UILabel!

    private var onRetry: (() -> Void)?
    private var onGuide: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.timeoverTitle),
            font: .systemFont(ofSize: 19, weight: .bold),
            color: titleLabel.textColor,
            alignment: .center
        )
        subtitleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.timeoverSubtitle),
            font: .systemFont(ofSize: 14),
            color: subtitleLabel.textColor,
            lineSpacing: 5,
            alignment: .center
        )
        confirmButton.setTitle(AIScanCameraStrings.localized(.timeoverRetry), for: .normal)
        guideLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.guide),
            font: .systemFont(ofSize: 13),
            color: guideLabel.textColor,
            alignment: .center
        )
        confirmButton.layer.cornerRadius = 10
        confirmButton.clipsToBounds = true
        view.accessibilityIdentifier = "aiscan.camera.timeover"
        confirmButton.accessibilityIdentifier = "aiscan.camera.timeover.retry"
        cancelButton.accessibilityIdentifier = "aiscan.camera.timeover.guide"
    }

    @IBAction func confirm(_ sender: Any) {
        dismiss(animated: true) { [onRetry] in onRetry?() }
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true) { [onGuide] in onGuide?() }
    }

    static func instantiate(
        onRetry: @escaping () -> Void,
        onGuide: @escaping () -> Void
    ) -> TTPopupTimeoverViewController {
        guard let controller = UIStoryboard(
            name: "TTPopup",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(
            withIdentifier: "TTPopupTimeoverViewController"
        ) as? TTPopupTimeoverViewController else {
            preconditionFailure("The original timeover popup is unavailable.")
        }
        controller.onRetry = onRetry
        controller.onGuide = onGuide
        return controller
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
        titleLabel.text = AIScanCameraStrings.localizedMessageKey("popup.skin.title")
        earTitleLabel.text = AIScanCameraStrings.localizedMessageKey("popup.skin.ear")
        earSubtitleLabel.text = AIScanCameraStrings.localizedMessageKey("popup.skin.ear_detail")
        bodyTitleLabel.text = AIScanCameraStrings.localizedMessageKey("popup.skin.body")
        bodySubtitleLabel.text = AIScanCameraStrings.localizedMessageKey("popup.skin.body_detail")
        footTitleLabel.text = AIScanCameraStrings.localizedMessageKey("popup.skin.foot")
        footSubtitleLabel.text = AIScanCameraStrings.localizedMessageKey("popup.skin.foot_detail")
        flashDescriptionLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localizedMessageKey("popup.skin.flash"),
            font: .systemFont(ofSize: 13),
            color: flashDescriptionLabel.textColor,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.flash.highlight"):
                    (.systemFont(ofSize: 13, weight: .semibold), AIScanLegacyText.accent)
            ]
        )
        descriptionLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashSubtitle),
            font: .systemFont(ofSize: 11),
            color: descriptionLabel.textColor,
            lineSpacing: 5,
            alignment: .left
        )
        warningLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localizedMessageKey("popup.skin.warning"),
            font: .systemFont(ofSize: 12),
            color: warningLabel.textColor,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.skin.warning_highlight"):
                    (.systemFont(ofSize: 12, weight: .bold), AIScanLegacyText.warning)
            ]
        )
        startButton.setTitle(AIScanCameraStrings.localized(.start), for: .normal)
        [earContainer, bodyContainer, footContainer, flashContainer].forEach {
            $0?.layer.cornerRadius = 17
            $0?.clipsToBounds = true
        }
        startButton.layer.cornerRadius = 10
        startButton.clipsToBounds = true
        startButton.isEnabled = false
        flashButton.isSelected = false
        flashContainer.layer.borderWidth = 1
        flashContainer.layer.borderColor = UIColor.separator.cgColor
        flashSwichImageView.image = bundledImage("toggle_Off")
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
            container?.backgroundColor = selected
                ? AIScanLegacyText.popupSurface
                : AIScanLegacyText.unselectedSurface
            check?.image = bundledImage(selected ? "circleFillCheckOn" : "circleFillCheckOff")
        }
        startButton.backgroundColor = selectedPosition == nil
            ? AIScanLegacyText.disabledAction
            : AIScanLegacyText.primaryAction
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(AIScanLegacyText.disabledText, for: .disabled)
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

private enum AIScanLegacyText {
    static let accent = UIColor(red: 54 / 255, green: 141 / 255, blue: 245 / 255, alpha: 1)
    static let warning = UIColor(red: 250 / 255, green: 83 / 255, blue: 95 / 255, alpha: 1)
    static let primaryAction = UIColor(red: 51 / 255, green: 51 / 255, blue: 68 / 255, alpha: 1)
    static let disabledAction = UIColor(red: 237 / 255, green: 237 / 255, blue: 237 / 255, alpha: 1)
    static let disabledText = UIColor(red: 180 / 255, green: 180 / 255, blue: 180 / 255, alpha: 1)
    static let unselectedSurface = UIColor(red: 242 / 255, green: 242 / 255, blue: 242 / 255, alpha: 1)
    static var popupSurface: UIColor {
        UIColor(
            named: "AISPopupSurface",
            in: AIScanCameraResourceBundle.bundle,
            compatibleWith: nil
        ) ?? .systemBackground
    }

    static func attributed(
        _ text: String,
        font: UIFont,
        color: UIColor,
        lineSpacing: CGFloat = 0,
        alignment: NSTextAlignment,
        highlights: [String: (UIFont, UIColor)] = [:]
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = alignment
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .kern: -0.5,
                .paragraphStyle: paragraph,
            ]
        )
        for (needle, style) in highlights where !needle.isEmpty {
            let range = (text as NSString).range(of: needle)
            guard range.location != NSNotFound else { continue }
            result.addAttributes([.font: style.0, .foregroundColor: style.1], range: range)
        }
        return result
    }
}

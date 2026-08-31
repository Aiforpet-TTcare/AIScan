import UIKit

private enum AIScanLegacyFont {
    static func regular(_ size: CGFloat) -> UIFont {
        UIFont(name: "HelveticaNeue", size: size) ?? .systemFont(ofSize: size)
    }

    static func bold(_ size: CGFloat) -> UIFont {
        UIFont(name: "HelveticaNeue-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    }

    static func medium(_ size: CGFloat) -> UIFont {
        UIFont(name: "HelveticaNeue-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }
}

@MainActor
private protocol AIScanLegacyPopupActionRouting: AnyObject {
    var popupDismiss: ((Bool, @escaping () -> Void) -> Void)? { get set }
}

@MainActor
protocol AIScanLegacyPopupDismissing: AnyObject {
    func dismiss(
        _ container: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    )
}

@MainActor
final class AIScanUIKitPopupDismisser: AIScanLegacyPopupDismissing {
    func dismiss(
        _ container: UIViewController,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        container.dismiss(animated: animated, completion: completion)
    }
}

@MainActor
private extension AIScanLegacyPopupActionRouting where Self: UIViewController {
    func dismissPopup(animated: Bool = true, completion: @escaping () -> Void) {
        if let popupDismiss {
            popupDismiss(animated, completion)
        } else {
            dismiss(animated: animated, completion: completion)
        }
    }
}

/// Action adapter for the unchanged original TTPopup alert scene.
@MainActor
enum AIScanLegacyAlertLayout {
    case vertical
    case horizontal
}

@MainActor
@objc(TTPopupAlertViewController)
final class TTPopupAlertViewController: UIViewController, AIScanLegacyPopupActionRouting {
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
    private var alertLayout: AIScanLegacyAlertLayout = .vertical
    private var primaryAccessibilityIdentifier: String?
    private var onPrimary: (() -> Void)?
    private var onSecondary: (() -> Void)?
    fileprivate var popupDismiss: ((Bool, @escaping () -> Void) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        if alertLayout == .horizontal {
            titleLabel.attributedText = configuredTitle.map {
                AIScanLegacyText.htmlAttributed(
                    $0,
                    font: AIScanLegacyFont.bold(19),
                    color: AIScanLegacyText.textPrimary,
                    alignment: .center
                )
            }
            subtitleLabel.attributedText = configuredSubtitle.map {
                AIScanLegacyText.htmlAttributed(
                    $0,
                    font: AIScanLegacyFont.medium(14),
                    color: AIScanLegacyText.textSecondary,
                    alignment: .center,
                    highlights: [
                        "#368DF5": (AIScanLegacyFont.bold(14), AIScanLegacyText.accent),
                    ]
                )
            }
        } else {
            titleLabel.attributedText = configuredTitle.map {
                AIScanLegacyText.attributed(
                    $0,
                    font: AIScanLegacyFont.bold(19),
                    color: AIScanLegacyText.textPrimary,
                    alignment: .center
                )
            }
            subtitleLabel.attributedText = configuredSubtitle.map {
                AIScanLegacyText.attributed(
                    $0,
                    font: AIScanLegacyFont.regular(14),
                    color: AIScanLegacyText.textSecondary,
                    lineSpacing: 5,
                    alignment: .center
                )
            }
        }
        view.backgroundColor = AIScanLegacyText.popupSurface
        subtitleLabel.isHidden = configuredSubtitle == nil
        iconContainer.isHidden = true
        view.accessibilityIdentifier = "aiscan.camera.popup"
        confirmButton.setTitle(primaryTitle, for: .normal)
        confirmButton.accessibilityIdentifier = primaryAccessibilityIdentifier
            ?? (secondaryTitle == nil ? "aiscan.camera.close" : "aiscan.camera.retry")
        confirmButton.setBackgroundImage(nil, for: .normal)
        confirmButton.backgroundColor = AIScanLegacyText.primaryAction
        confirmButton.setTitleColor(AIScanLegacyText.onPrimaryAction, for: .normal)
        confirmButton.layer.cornerRadius = 10
        confirmButton.clipsToBounds = true
        if alertLayout == .horizontal {
            cancelButton.setAttributedTitle(nil, for: .normal)
            cancelButton.setTitle(secondaryTitle, for: .normal)
            cancelButton.setBackgroundImage(nil, for: .normal)
            cancelButton.backgroundColor = AIScanLegacyText.secondaryAction
            cancelButton.setTitleColor(AIScanLegacyText.textSecondary, for: .normal)
            cancelButton.layer.cornerRadius = 10
            cancelButton.clipsToBounds = true
            confirmButton.titleLabel?.adjustsFontForContentSizeCategory = true
            confirmButton.titleLabel?.minimumScaleFactor = 0.5
            confirmButton.titleLabel?.numberOfLines = 2
            cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        } else {
            cancelButton.setAttributedTitle(secondaryTitle.map {
                AIScanLegacyText.attributed(
                    $0,
                    font: AIScanLegacyFont.regular(13),
                    color: AIScanLegacyText.textSecondary,
                    alignment: .center,
                    underline: true
                )
            }, for: .normal)
        }
        cancelButton.accessibilityIdentifier = "aiscan.camera.close"
        cancelButton.isHidden = secondaryTitle == nil
        view.layer.cornerRadius = 33
        view.clipsToBounds = true
    }

    @IBAction func confirm(_ sender: Any) {
        dismissPopup { [onPrimary] in onPrimary?() }
    }

    @IBAction func cancel(_ sender: Any) {
        dismissPopup { [onSecondary] in onSecondary?() }
    }

    static func instantiate(
        title: String,
        subtitle: String? = nil,
        primaryTitle: String,
        secondaryTitle: String?,
        layout: AIScanLegacyAlertLayout = .vertical,
        primaryAccessibilityIdentifier: String? = nil,
        onPrimary: (() -> Void)?,
        onSecondary: (() -> Void)?
    ) -> TTPopupAlertViewController {
        guard let controller = UIStoryboard(
            name: "TTPopup",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(
            withIdentifier: layout == .horizontal
                ? "TTPopupAlertHorizontalViewController"
                : "TTPopupAlertViewController"
        ) as? TTPopupAlertViewController else {
            preconditionFailure("The original TTPopup alert scene is unavailable.")
        }
        controller.configuredTitle = title
        controller.configuredSubtitle = subtitle
        controller.primaryTitle = primaryTitle
        controller.secondaryTitle = secondaryTitle
        controller.alertLayout = layout
        controller.primaryAccessibilityIdentifier = primaryAccessibilityIdentifier
        controller.onPrimary = onPrimary
        controller.onSecondary = onSecondary
        return controller
    }
}

@MainActor
struct AIScanRetakeGuideItem {
    let title: String
    let wrongTitle: String
    let rightTitle: String
    let wrongImage: UIImage?
    let rightImage: UIImage?
}

/// Action adapter for the unchanged original checked-result storyboard scene.
@MainActor
@objc(TTPopupCheckedResultViewController)
final class TTPopupCheckedResultViewController: UIViewController, AIScanLegacyPopupActionRouting {
    @IBOutlet weak var indicatorContainer: UIView!
    @IBOutlet weak var bodyView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var guideContainer: UIStackView!
    @IBOutlet weak var guideButton: UIButton!

    private var items: [AIScanRetakeGuideItem] = []
    private var onRetake: (() -> Void)?
    private var indicator: TTIndicatorView?
    fileprivate var popupDismiss: ((Bool, @escaping () -> Void) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "aiscan.camera.retake"
        view.backgroundColor = AIScanLegacyText.popupSurface
        bodyView.backgroundColor = AIScanLegacyText.popupSurface
        collectionView.backgroundColor = AIScanLegacyText.popupSurface
        indicatorContainer.backgroundColor = AIScanLegacyText.popupSurface
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        let indicator = TTIndicatorView(numberOfCircles: items.count)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicatorContainer.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: indicatorContainer.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: indicatorContainer.centerYAnchor),
        ])
        self.indicator = indicator
        indicatorContainer.isHidden = items.count <= 1
        guideButton.isHidden = true
        guideContainer.isHidden = true
        confirmButton.setTitle(AIScanCameraStrings.localized(.retakeAction), for: .normal)
        confirmButton.accessibilityIdentifier = "aiscan.camera.retake.confirm"
        confirmButton.backgroundColor = AIScanLegacyText.retakeAction
        confirmButton.setTitleColor(AIScanLegacyText.onPrimaryAction, for: .normal)
        confirmButton.layer.cornerRadius = 25
        confirmButton.clipsToBounds = true
        view.layer.cornerRadius = 33
        view.clipsToBounds = true
        collectionView.reloadData()
    }

    @IBAction func confirm(_ sender: Any) {
        dismissPopup { [onRetake] in onRetake?() }
    }

    @IBAction func showGuide(_ sender: UIButton) {}

    static func instantiate(
        item: AIScanRetakeGuideItem,
        onRetake: @escaping () -> Void
    ) -> TTPopupCheckedResultViewController {
        instantiate(items: [item], onRetake: onRetake)
    }

    static func instantiate(
        items: [AIScanRetakeGuideItem],
        onRetake: @escaping () -> Void
    ) -> TTPopupCheckedResultViewController {
        guard let controller = UIStoryboard(
            name: "TTPopup",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(
            withIdentifier: "TTPopupCheckedResultViewController"
        ) as? TTPopupCheckedResultViewController else {
            preconditionFailure("The original checked-result popup scene is unavailable.")
        }
        controller.items = items
        controller.onRetake = onRetake
        return controller
    }
}

extension TTPopupCheckedResultViewController:
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "TTPopupCheckedResultCell",
            for: indexPath
        )
        guard let checkedCell = cell as? TTPopupCheckedResultCell,
              items.indices.contains(indexPath.item) else { return cell }
        checkedCell.configure(item: items[indexPath.item])
        return checkedCell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        let page = Int((scrollView.contentOffset.x + pageWidth / 2) / pageWidth)
        indicator?.updateIndicator(forPage: page)
    }
}

@MainActor
@objc(TTPopupCheckedResultCell)
final class TTPopupCheckedResultCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var wrongIcon: UIImageView!
    @IBOutlet weak var wrongIconShadow: UIView!
    @IBOutlet weak var wrongTitleLabel: UILabel!
    @IBOutlet weak var wellIcon: UIImageView!
    @IBOutlet weak var wellIconShadow: UIView!
    @IBOutlet weak var wellTitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        for view in [wrongIcon, wrongIconShadow, wellIcon, wellIconShadow] {
            view?.layer.cornerRadius = 33
            view?.clipsToBounds = true
        }
        backgroundColor = AIScanLegacyText.popupSurface
        contentView.backgroundColor = AIScanLegacyText.popupSurface
        wrongIconShadow.backgroundColor = AIScanLegacyText.checkedIconShadow
        wellIconShadow.backgroundColor = AIScanLegacyText.checkedIconShadow
        titleLabel.textColor = AIScanLegacyText.textPrimary
        wrongTitleLabel.textColor = AIScanLegacyText.textPrimary
        wellTitleLabel.textColor = AIScanLegacyText.textPrimary
        wrongIcon.accessibilityIdentifier = "aiscan.camera.retake.captured"
        wellIcon.accessibilityIdentifier = "aiscan.camera.retake.reference"
        wellIcon.contentMode = .scaleAspectFill
        wellIcon.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        wrongIcon.image = nil
        wellIcon.image = nil
    }

    func configure(item: AIScanRetakeGuideItem) {
        titleLabel.attributedText = AIScanLegacyText.attributed(
            item.title,
            font: AIScanLegacyFont.bold(18),
            color: AIScanLegacyText.textPrimary,
            alignment: .center
        )
        wrongTitleLabel.text = item.wrongTitle
        wellTitleLabel.text = item.rightTitle
        wrongIcon.image = item.wrongImage
        wellIcon.image = item.rightImage
    }
}

/// Original popup-manager bottom geometry for the checked-result card.
@MainActor
final class AIScanLegacyBottomPopupContainer: UIViewController {
    private let content: UIViewController
    private let cardHeight: CGFloat
    private let popupDismisser: AIScanLegacyPopupDismissing

    init(
        content: UIViewController,
        cardHeight: CGFloat = 363,
        popupDismisser: AIScanLegacyPopupDismissing? = nil
    ) {
        self.content = content
        self.cardHeight = cardHeight
        self.popupDismisser = popupDismisser ?? AIScanUIKitPopupDismisser()
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var shouldAutorotate: Bool { false }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        if let routedContent = content as? AIScanLegacyPopupActionRouting {
            routedContent.popupDismiss = { [weak self] animated, completion in
                self?.dismissCard(animated: animated, completion: completion)
            }
        }
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        content.view.layer.cornerRadius = 33
        content.view.layer.masksToBounds = true
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.heightAnchor.constraint(equalToConstant: cardHeight),
        ])
        content.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard animated else { return }
        content.view.transform = CGAffineTransform(translationX: 0, y: cardHeight)
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.content.view.transform = .identity
        }
    }

    private func dismissCard(animated: Bool, completion: @escaping () -> Void) {
        let finish = { [popupDismisser, weak self] in
            guard let self else {
                completion()
                return
            }
            popupDismisser.dismiss(self, animated: false, completion: completion)
        }
        guard animated else {
            finish()
            return
        }
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                self.content.view.transform = CGAffineTransform(translationX: 0, y: self.cardHeight)
                self.view.backgroundColor = .clear
            },
            completion: { _ in finish() }
        )
    }
}

/// Original popup-manager geometry around the original storyboard card.
@MainActor
final class AIScanLegacyPopupContainer: UIViewController {
    private let content: UIViewController
    private let cardWidth: CGFloat
    private let cardCornerRadius: CGFloat
    private let presentationSpringDamping: CGFloat
    private let popupDismisser: AIScanLegacyPopupDismissing
    private var didAnimatePresentation = false

    init(
        content: UIViewController,
        cardWidth: CGFloat = 315,
        cardCornerRadius: CGFloat = 33,
        presentationSpringDamping: CGFloat = 0.5,
        popupDismisser: AIScanLegacyPopupDismissing? = nil
    ) {
        self.content = content
        self.cardWidth = cardWidth
        self.cardCornerRadius = cardCornerRadius
        self.presentationSpringDamping = presentationSpringDamping
        self.popupDismisser = popupDismisser ?? AIScanUIKitPopupDismisser()
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
        view.backgroundColor = .clear
        if let routedContent = content as? AIScanLegacyPopupActionRouting {
            routedContent.popupDismiss = { [weak self] animated, completion in
                guard let self else {
                    completion()
                    return
                }
                self.dismissCard(animated: animated, completion: completion)
            }
        }
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        content.view.layer.cornerRadius = cardCornerRadius
        content.view.layer.masksToBounds = true
        view.addSubview(content.view)
        let preferredWidth = content.view.widthAnchor.constraint(equalToConstant: cardWidth)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            content.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            content.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            preferredWidth,
            content.view.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 16
            ),
            content.view.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            content.view.topAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 16
            ),
            content.view.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),
        ])
        content.didMove(toParent: self)
        content.view.alpha = 0
        content.view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didAnimatePresentation else { return }
        didAnimatePresentation = true
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        if reduceMotion {
            content.view.transform = .identity
        }
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: reduceMotion ? 1 : presentationSpringDamping,
            initialSpringVelocity: reduceMotion ? 0 : 0.5,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
                self.content.view.alpha = 1
                self.content.view.transform = .identity
                self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            }
        )
    }

    private func dismissCard(animated: Bool, completion: @escaping () -> Void) {
        let finish = { [popupDismisser, weak self] in
            guard let self else {
                completion()
                return
            }
            popupDismisser.dismiss(self, animated: false, completion: completion)
        }
        guard animated else {
            finish()
            return
        }
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
                self.content.view.alpha = 0
                if !UIAccessibility.isReduceMotionEnabled {
                    self.content.view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                }
                self.view.backgroundColor = .clear
            },
            completion: { _ in finish() }
        )
    }
}

@MainActor
@objc(TTFlashWarningAlertViewController)
final class TTFlashWarningAlertViewController: UIViewController, AIScanLegacyPopupActionRouting {
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
    fileprivate var popupDismiss: ((Bool, @escaping () -> Void) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashTitle),
            font: AIScanLegacyFont.bold(18),
            color: AIScanLegacyText.textPrimary,
            alignment: .center
        )
        subtitleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashSubtitle),
            font: AIScanLegacyFont.regular(11),
            color: AIScanLegacyText.textSecondary,
            lineSpacing: 5,
            alignment: .left
        )
        flashWarningLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashBenefit),
            font: AIScanLegacyFont.regular(13),
            color: AIScanLegacyText.textSecondary,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.flash.highlight"):
                    (AIScanLegacyFont.regular(13), AIScanLegacyText.accent)
            ]
        )
        skinWarningLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localizedMessageKey("popup.skin.warning"),
            font: AIScanLegacyFont.regular(12),
            color: AIScanLegacyText.textSecondary,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.skin.warning_highlight"):
                    (AIScanLegacyFont.bold(12), AIScanLegacyText.warning)
            ]
        )
        confirmButton.setTitle(AIScanCameraStrings.localized(.start), for: .normal)
        confirmButton.setBackgroundImage(nil, for: .normal)
        confirmButton.backgroundColor = AIScanLegacyText.primaryAction
        confirmButton.setTitleColor(AIScanLegacyText.onPrimaryAction, for: .normal)
        confirmButton.layer.cornerRadius = 10
        confirmButton.clipsToBounds = true
        view.backgroundColor = AIScanLegacyText.popupSurface
        skinContainer.backgroundColor = AIScanLegacyText.popupSurface
        flashContainer.backgroundColor = AIScanLegacyText.popupSurface
        flashContainer.layer.cornerRadius = 17
        flashContainer.clipsToBounds = true
        flashContainer.layer.borderWidth = 1
        flashContainer.layer.borderColor = AIScanLegacyText.resolvedDivider(for: traitCollection)
        skinContainer.isHidden = !showsSkinGuidance
        flashButton.isSelected = startsWithFlash
        updateFlashImage()
        view.accessibilityIdentifier = "aiscan.camera.flash-warning"
        confirmButton.accessibilityIdentifier = "aiscan.camera.flash-warning.start"
        flashButton.accessibilityIdentifier = "aiscan.camera.flash-warning.toggle"
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard isViewLoaded,
              previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        flashContainer.layer.borderColor = AIScanLegacyText.resolvedDivider(for: traitCollection)
    }

    @IBAction func confirm(_ sender: Any) {
        dismissPopup { [onStart, flashButton] in
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
final class TTPopupTimeoverViewController: UIViewController, AIScanLegacyPopupActionRouting {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var guideLabel: UILabel!

    private var onRetry: (() -> Void)?
    private var onGuide: (() -> Void)?
    fileprivate var popupDismiss: ((Bool, @escaping () -> Void) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.timeoverTitle),
            font: AIScanLegacyFont.bold(19),
            color: AIScanLegacyText.textPrimary,
            alignment: .center
        )
        subtitleLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.timeoverSubtitle),
            font: AIScanLegacyFont.regular(14),
            color: AIScanLegacyText.textSecondary,
            lineSpacing: 5,
            alignment: .center
        )
        confirmButton.setTitle(AIScanCameraStrings.localized(.timeoverRetry), for: .normal)
        confirmButton.setBackgroundImage(nil, for: .normal)
        confirmButton.backgroundColor = AIScanLegacyText.primaryAction
        confirmButton.setTitleColor(AIScanLegacyText.onPrimaryAction, for: .normal)
        guideLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.guide),
            font: AIScanLegacyFont.regular(13),
            color: AIScanLegacyText.textSecondary,
            alignment: .center
        )
        view.backgroundColor = AIScanLegacyText.popupSurface
        confirmButton.layer.cornerRadius = 10
        confirmButton.clipsToBounds = true
        view.accessibilityIdentifier = "aiscan.camera.timeover"
        confirmButton.accessibilityIdentifier = "aiscan.camera.timeover.retry"
        cancelButton.accessibilityIdentifier = "aiscan.camera.timeover.guide"
    }

    @IBAction func confirm(_ sender: Any) {
        dismissPopup { [onRetry] in onRetry?() }
    }

    @IBAction func cancel(_ sender: Any) {
        dismissPopup { [onGuide] in onGuide?() }
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
final class TTPopupSelectedSkinViewController: UIViewController, AIScanLegacyPopupActionRouting {
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
    private var initialPosition: String?
    private var startsWithFlash = false
    private var selectedPosition: String?
    fileprivate var popupDismiss: ((Bool, @escaping () -> Void) -> Void)?

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
            font: AIScanLegacyFont.regular(13),
            color: AIScanLegacyText.textSecondary,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.flash.highlight"):
                    (AIScanLegacyFont.regular(13), AIScanLegacyText.accent)
            ]
        )
        descriptionLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localized(.flashSubtitle),
            font: AIScanLegacyFont.regular(11),
            color: AIScanLegacyText.textSecondary,
            lineSpacing: 5,
            alignment: .left
        )
        warningLabel.attributedText = AIScanLegacyText.attributed(
            AIScanCameraStrings.localizedMessageKey("popup.skin.warning"),
            font: AIScanLegacyFont.regular(12),
            color: AIScanLegacyText.textSecondary,
            lineSpacing: 5,
            alignment: .left,
            highlights: [
                AIScanCameraStrings.localizedMessageKey("popup.skin.warning_highlight"):
                    (AIScanLegacyFont.bold(12), AIScanLegacyText.warning)
            ]
        )
        startButton.setTitle(AIScanCameraStrings.localized(.start), for: .normal)
        startButton.setBackgroundImage(nil, for: .normal)
        startButton.setBackgroundImage(nil, for: .disabled)
        startButton.setTitleColor(AIScanLegacyText.onPrimaryAction, for: .normal)
        startButton.setTitleColor(AIScanLegacyText.textTertiary, for: .disabled)
        view.backgroundColor = AIScanLegacyText.popupSurface
        titleLabel.textColor = AIScanLegacyText.textPrimary
        [earTitleLabel, bodyTitleLabel, footTitleLabel].forEach {
            $0?.textColor = AIScanLegacyText.textPrimary
        }
        [earSubtitleLabel, bodySubtitleLabel, footSubtitleLabel].forEach {
            $0?.textColor = AIScanLegacyText.textSecondary
        }
        descriptionLabel.textColor = AIScanLegacyText.textSecondary
        flashContainer.backgroundColor = AIScanLegacyText.popupSurface
        [earContainer, bodyContainer, footContainer, flashContainer].forEach {
            $0?.layer.cornerRadius = 17
            $0?.clipsToBounds = true
        }
        startButton.layer.cornerRadius = 10
        startButton.clipsToBounds = true
        view.accessibilityIdentifier = "aiscan.camera.skin-selection"
        earContainer.accessibilityIdentifier = "aiscan.camera.skin-selection.ear"
        bodyContainer.accessibilityIdentifier = "aiscan.camera.skin-selection.belly"
        footContainer.accessibilityIdentifier = "aiscan.camera.skin-selection.foot"
        startButton.accessibilityIdentifier = "aiscan.camera.skin-selection.start"
        flashButton.accessibilityIdentifier = "aiscan.camera.skin-selection.flash"
        selectedPosition = initialPosition
        startButton.isEnabled = selectedPosition != nil
        flashButton.isSelected = startsWithFlash
        flashContainer.layer.borderWidth = 1
        flashContainer.layer.borderColor = AIScanLegacyText.resolvedDivider(for: traitCollection)
        flashSwichImageView.image = bundledImage(startsWithFlash ? "toggle_On" : "toggle_Off")
        applySelection()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard isViewLoaded,
              previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        flashContainer.layer.borderColor = AIScanLegacyText.resolvedDivider(for: traitCollection)
        applySelection()
    }

    @IBAction func close(_ sender: Any) {
        let callback = onClose
        onClose = nil
        callback?()
        dismissPopup {}
    }

    @IBAction func start(_ sender: Any) {
        guard let selectedPosition else { return }
        let flash = flashButton.isSelected
        let callback = onStart
        onStart = nil
        callback?(selectedPosition, flash)
        dismissPopup {}
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
            container?.layer.borderColor = AIScanLegacyText.resolvedDivider(for: traitCollection)
            container?.backgroundColor = selected
                ? AIScanLegacyText.popupSurface
                : AIScanLegacyText.unselectedSurface
            check?.image = bundledImage(selected ? "circleFillCheckOn" : "circleFillCheckOff")
        }
        startButton.backgroundColor = selectedPosition == nil
            ? AIScanLegacyText.disabledAction
            : AIScanLegacyText.primaryAction
        startButton.setTitleColor(AIScanLegacyText.onPrimaryAction, for: .normal)
        startButton.setTitleColor(AIScanLegacyText.disabledText, for: .disabled)
    }

    private func bundledImage(_ name: String) -> UIImage? {
        UIImage(named: name, in: AIScanCameraResourceBundle.bundle, compatibleWith: nil)
    }

    static func instantiate(
        initialPosition: String? = nil,
        startsWithFlash: Bool = false,
        onStart: @escaping (String, Bool) -> Void,
        onClose: @escaping () -> Void
    ) -> TTPopupSelectedSkinViewController {
        guard let controller = UIStoryboard(
            name: "TTPopup",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: "TTPopupSelectedSkinViewController") as? TTPopupSelectedSkinViewController else {
            preconditionFailure("The original skin-selection popup is unavailable.")
        }
        controller.initialPosition = initialPosition
        controller.startsWithFlash = startsWithFlash
        controller.onStart = onStart
        controller.onClose = onClose
        return controller
    }
}

enum AIScanLegacyText {
    static var accent: UIColor {
        adaptive(light: rgb(0x368DF5), dark: named("AISBrandAccent", fallback: .systemBlue))
    }
    static var warning: UIColor { adaptive(light: rgb(0xFA535F), dark: .systemRed) }
    static var primaryAction: UIColor {
        adaptive(light: rgb(0x333344), dark: named("AISBrandPrimary", fallback: .systemBlue))
    }
    static var retakeAction: UIColor { rgb(0x333444) }
    static var onPrimaryAction: UIColor {
        named("AISOnBrand", fallback: .white)
    }
    static var disabledAction: UIColor {
        adaptive(light: rgb(0xD3D3D3), dark: named("AISDisabledSurface", fallback: .systemGray5))
    }
    static var secondaryAction: UIColor {
        adaptive(light: rgb(0xF5F6F8), dark: .tertiarySystemBackground)
    }
    static var textPrimary: UIColor { adaptive(light: rgb(0x191919), dark: .label) }
    static var textSecondary: UIColor { adaptive(light: rgb(0x717171), dark: .secondaryLabel) }
    static var textTertiary: UIColor { adaptive(light: rgb(0x999999), dark: .tertiaryLabel) }
    static var disabledText: UIColor { textTertiary }
    static var unselectedSurface: UIColor {
        adaptive(light: rgb(0xF2F2F2), dark: .tertiarySystemBackground)
    }
    static var checkedIconShadow: UIColor {
        adaptive(light: rgb(0xB4B4B4), dark: named("AISDisabledSurface", fallback: .systemGray5))
    }
    static var indicatorInactive: UIColor {
        adaptive(light: rgb(0x333344), dark: .separator)
    }
    static var indicatorActive: UIColor {
        adaptive(light: rgb(0xC8C8C8), dark: named("AISBrandPrimary", fallback: .systemBlue))
    }
    static var divider: UIColor { adaptive(light: rgb(0xEDEDED), dark: .separator) }
    static var popupSurface: UIColor {
        named("AISPopupSurface", fallback: .systemBackground)
    }

    static func resolvedDivider(for traits: UITraitCollection) -> CGColor {
        divider.resolvedColor(with: traits).cgColor
    }

    static func attributed(
        _ text: String,
        font: UIFont,
        color: UIColor,
        lineSpacing: CGFloat = 0,
        alignment: NSTextAlignment,
        highlights: [String: (UIFont, UIColor)] = [:],
        underline: Bool = false
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        if #available(iOS 14.0, *) {
            paragraph.lineBreakStrategy = .hangulWordPriority
        }
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .kern: -0.5,
                .paragraphStyle: paragraph,
            ]
        )
        if underline {
            result.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: result.length)
            )
        }
        for (needle, style) in highlights where !needle.isEmpty {
            let range = (text as NSString).range(of: needle)
            guard range.location != NSNotFound else { continue }
            result.addAttributes([.font: style.0, .foregroundColor: style.1], range: range)
        }
        return result
    }

    static func htmlAttributed(
        _ html: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment,
        highlights: [String: (UIFont, UIColor)] = [:]
    ) -> NSAttributedString {
        var source = """
        <style>
            body {
                font-family: '\(font.fontName)', 'Helvetica Neue';
                font-size: \(font.pointSize)px;
            }
        """
        for (hex, style) in highlights {
            source += "font[color='\(hex)'] { font-family: '\(style.0.fontName)'; } "
        }
        source += "</style>\(html)"

        guard let data = source.data(using: .utf8),
              let parsed = try? NSMutableAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
              ) else {
            return attributed(
                html,
                font: font,
                color: color,
                lineSpacing: 5,
                alignment: alignment
            )
        }

        let fullRange = NSRange(location: 0, length: parsed.length)
        parsed.addAttribute(.kern, value: -0.5, range: fullRange)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.alignment = alignment
        parsed.addAttribute(.paragraphStyle, value: paragraph, range: fullRange)
        parsed.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            let sourceColor = value as? UIColor
            let replacement = highlights.first { hex, _ in
                guard let candidate = Self.color(hex: hex) else { return false }
                return sourceColor.map { colorsAreEqual($0, candidate) } ?? false
            }?.value.1 ?? color
            parsed.addAttribute(.foregroundColor, value: replacement, range: range)
        }
        return parsed
    }

    private static func named(_ name: String, fallback: UIColor) -> UIColor {
        UIColor(
            named: name,
            in: AIScanCameraResourceBundle.bundle,
            compatibleWith: nil
        ) ?? fallback
    }

    private static func color(hex: String) -> UIColor? {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard normalized.count == 6, let value = UInt32(normalized, radix: 16) else { return nil }
        return rgb(value)
    }

    private static func colorsAreEqual(_ first: UIColor, _ second: UIColor) -> Bool {
        var lhs: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var rhs: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        guard first.getRed(&lhs.0, green: &lhs.1, blue: &lhs.2, alpha: &lhs.3),
              second.getRed(&rhs.0, green: &rhs.1, blue: &rhs.2, alpha: &rhs.3) else {
            return first.isEqual(second)
        }
        let tolerance: CGFloat = 0.01
        return abs(lhs.0 - rhs.0) < tolerance
            && abs(lhs.1 - rhs.1) < tolerance
            && abs(lhs.2 - rhs.2) < tolerance
            && abs(lhs.3 - rhs.3) < tolerance
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            let color = traits.userInterfaceStyle == .dark ? dark : light
            return color.resolvedColor(with: traits)
        }
    }

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

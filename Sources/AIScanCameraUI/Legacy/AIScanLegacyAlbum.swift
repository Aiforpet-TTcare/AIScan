import PhotosUI
import UIKit
import UniformTypeIdentifiers

@available(iOS 14, *)
enum AIScanAlbumImageLoader {
    private final class ItemProviderBox: @unchecked Sendable {
        let value: NSItemProvider

        init(_ value: NSItemProvider) {
            self.value = value
        }
    }

    nonisolated static func loadFullResolutionImage(
        from provider: NSItemProvider,
        completion: @escaping @MainActor @Sendable (UIImage?) -> Void
    ) {
        let imageType = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .image) == true
        } ?? UTType.image.identifier

        let providerBox = ItemProviderBox(provider)
        provider.loadFileRepresentation(forTypeIdentifier: imageType) { url, _ in
            if let url,
               let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let image = UIImage(data: data) {
                Task { @MainActor in completion(image) }
                return
            }

            let provider = providerBox.value
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                Task { @MainActor in completion(nil) }
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                Task { @MainActor in completion(image) }
            }
        }
    }
}

@MainActor
final class AIScanAlbumSelectionViewController: UIViewController {
    var onClose: (() -> Void)?
    var onAnalyze: ((UIImage, String?) -> Void)?

    private let allowsPositionSelection: Bool
    private var selectedPosition: String?
    private var selectedImage: UIImage?
    private let contentStack = UIStackView()
    private let areaStack = UIStackView()
    private let photoCard = UIView()
    private let photoImageView = UIImageView()
    private let emptyStack = UIStackView()
    private let emptyIconBackground = UIView()
    private let emptyIconBackgroundLayer = CAShapeLayer()
    private let validationRow = UIStackView()
    private let validationLabel = UILabel()
    private let selectPhotoButton = UIButton(type: .system)
    private let dashedBorderLayer = CAShapeLayer()
    private let photoBorderLayer = CAShapeLayer()
    private let analyzeButton = UIButton(type: .system)
    private let analyzeBackgroundLayer = CAShapeLayer()
    private let analyzeLabel = UILabel()
    private var areaButtons: [String: UIButton] = [:]
    private var isAnalyzing = false

    init(allowsPositionSelection: Bool, initialPosition: String?) {
        self.allowsPositionSelection = allowsPositionSelection
        selectedPosition = Self.canonicalPosition(initialPosition)
            ?? (allowsPositionSelection ? "belly" : initialPosition)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIScanReferenceTheme.background
        buildHeader()
        buildContent()
        updateSelectionUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if selectPhotoButton.bounds.width.isFinite,
           selectPhotoButton.bounds.height.isFinite,
           selectPhotoButton.bounds.width > 1,
           selectPhotoButton.bounds.height > 1 {
            dashedBorderLayer.frame = selectPhotoButton.bounds
            let dashedBounds = selectPhotoButton.bounds.insetBy(dx: 0.5, dy: 0.5)
            dashedBorderLayer.path = UIBezierPath(
                roundedRect: dashedBounds,
                cornerRadius: 11.5
            ).cgPath
        }
        if photoCard.bounds.width.isFinite,
           photoCard.bounds.height.isFinite,
           photoCard.bounds.width > 0,
           photoCard.bounds.height > 0 {
            photoBorderLayer.frame = photoCard.bounds
            photoBorderLayer.path = UIBezierPath(
                roundedRect: photoCard.bounds,
                cornerRadius: 12
            ).cgPath
        }
        if emptyIconBackground.bounds.width.isFinite,
           emptyIconBackground.bounds.height.isFinite,
           emptyIconBackground.bounds.width > 0,
           emptyIconBackground.bounds.height > 0 {
            emptyIconBackgroundLayer.frame = emptyIconBackground.bounds
            emptyIconBackgroundLayer.path = UIBezierPath(
                ovalIn: emptyIconBackground.bounds
            ).cgPath
        }
        if analyzeButton.bounds.width.isFinite,
           analyzeButton.bounds.height.isFinite,
           analyzeButton.bounds.width > 0,
           analyzeButton.bounds.height > 0 {
            analyzeBackgroundLayer.frame = analyzeButton.bounds
            analyzeBackgroundLayer.path = UIBezierPath(
                roundedRect: analyzeButton.bounds,
                cornerRadius: 14
            ).cgPath
        }
        updateLayerColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        updateSelectionUI()
        updateLayerColors()
    }

    func setValidationMessage(_ message: String?) {
        if let message {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            validationLabel.attributedText = NSAttributedString(
                string: message,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 17, weight: .bold),
                    .foregroundColor: AIScanReferenceTheme.warning,
                    .paragraphStyle: paragraph,
                ]
            )
        } else {
            validationLabel.attributedText = nil
        }
        validationRow.isHidden = message?.isEmpty != false
    }

    func setAnalyzing(_ analyzing: Bool) {
        isAnalyzing = analyzing
        updateSelectionUI()
    }

    private func buildHeader() {
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = AIScanReferenceTheme.textPrimary
        closeButton.setImage(
            UIImage(
                named: "commonNavigationbarIconNavigationbarCloseIcon",
                in: AIScanCameraResourceBundle.bundle,
                compatibleWith: nil
            ) ?? UIImage(systemName: "xmark"),
            for: .normal
        )
        closeButton.accessibilityLabel = AIScanCameraStrings.localized(.close)
        closeButton.accessibilityIdentifier = "aiscan.album.close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        view.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    private func buildContent() {
        if allowsPositionSelection {
            buildAreaSelector()
            contentStack.addArrangedSubview(areaStack)
            contentStack.setCustomSpacing(19, after: areaStack)
        }

        selectPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        selectPhotoButton.layer.cornerRadius = 12
        selectPhotoButton.backgroundColor = AIScanReferenceTheme.surface
        selectPhotoButton.accessibilityIdentifier = "aiscan.album.select-photo"
        selectPhotoButton.accessibilityLabel = AIScanCameraStrings.localizedMessageKey("album.select_photo")
        selectPhotoButton.addTarget(self, action: #selector(selectPhotoTapped), for: .touchUpInside)
        selectPhotoButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        let selectIcon = UIImageView(image: UIImage(
            systemName: "plus.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17)
        ))
        selectIcon.tintColor = AIScanReferenceTheme.textTertiary
        selectIcon.setContentHuggingPriority(.required, for: .horizontal)
        let selectLabel = UILabel()
        selectLabel.text = AIScanCameraStrings.localizedMessageKey("album.select_photo")
        selectLabel.textColor = AIScanReferenceTheme.textTertiary
        selectLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        selectLabel.accessibilityIdentifier = "aiscan.album.select-photo.label"
        let selectContent = UIStackView(arrangedSubviews: [selectIcon, selectLabel])
        selectContent.translatesAutoresizingMaskIntoConstraints = false
        selectContent.axis = .horizontal
        selectContent.alignment = .center
        selectContent.spacing = 4
        selectContent.isUserInteractionEnabled = false
        selectPhotoButton.addSubview(selectContent)
        NSLayoutConstraint.activate([
            selectContent.centerXAnchor.constraint(equalTo: selectPhotoButton.centerXAnchor),
            selectContent.centerYAnchor.constraint(equalTo: selectPhotoButton.centerYAnchor),
        ])
        dashedBorderLayer.strokeColor = AIScanReferenceTheme.controlBorder.cgColor
        dashedBorderLayer.fillColor = UIColor.clear.cgColor
        dashedBorderLayer.lineWidth = 1
        dashedBorderLayer.lineDashPattern = [4]
        dashedBorderLayer.lineDashPhase = 7
        dashedBorderLayer.name = "aiscan.album.select-photo-border"
        selectPhotoButton.layer.addSublayer(dashedBorderLayer)
        contentStack.addArrangedSubview(selectPhotoButton)

        buildPhotoCard()
        contentStack.addArrangedSubview(photoCard)
        let photoHeight = photoCard.heightAnchor.constraint(equalToConstant: 380)
        photoHeight.priority = .defaultHigh
        photoHeight.isActive = true

        buildValidationRow()
        contentStack.addArrangedSubview(validationRow)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        contentStack.addArrangedSubview(spacer)

        analyzeButton.backgroundColor = .clear
        analyzeButton.accessibilityIdentifier = "aiscan.album.analyze"
        analyzeButton.accessibilityLabel = AIScanCameraStrings.localizedMessageKey("album.analyze")
        analyzeButton.addTarget(self, action: #selector(analyzeTapped), for: .touchUpInside)
        analyzeButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
        analyzeBackgroundLayer.name = "aiscan.album.analyze-background"
        analyzeBackgroundLayer.fillColor = AIScanReferenceTheme.disabledSurface.cgColor
        analyzeButton.layer.insertSublayer(analyzeBackgroundLayer, at: 0)
        analyzeLabel.translatesAutoresizingMaskIntoConstraints = false
        analyzeLabel.text = AIScanCameraStrings.localizedMessageKey("album.analyze")
        analyzeLabel.font = .systemFont(ofSize: 17, weight: .bold)
        analyzeLabel.textAlignment = .center
        analyzeLabel.isUserInteractionEnabled = false
        analyzeLabel.accessibilityIdentifier = "aiscan.album.analyze.label"
        analyzeButton.addSubview(analyzeLabel)
        NSLayoutConstraint.activate([
            analyzeLabel.centerXAnchor.constraint(equalTo: analyzeButton.centerXAnchor),
            analyzeLabel.centerYAnchor.constraint(equalTo: analyzeButton.centerYAnchor),
        ])
        contentStack.addArrangedSubview(analyzeButton)
    }

    private func buildAreaSelector() {
        areaStack.axis = .horizontal
        areaStack.spacing = 9
        areaStack.distribution = .fillEqually
        for item in [("ear", "album.ear"), ("belly", "album.body"), ("foot", "album.paws")] {
            let button = UIButton(type: .system)
            button.setTitle(AIScanCameraStrings.localizedMessageKey(item.1), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            button.layer.cornerRadius = 12
            button.accessibilityIdentifier = "aiscan.album.area.\(item.0)"
            button.addTarget(self, action: #selector(areaTapped(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(equalToConstant: 48).isActive = true
            areaButtons[item.0] = button
            areaStack.addArrangedSubview(button)
        }
    }

    private func buildPhotoCard() {
        photoCard.backgroundColor = AIScanReferenceTheme.surface
        photoCard.layer.cornerRadius = 12
        photoCard.clipsToBounds = false
        photoCard.accessibilityIdentifier = "aiscan.album.photo-card"
        photoCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectPhotoTapped)))

        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = 12
        photoImageView.isHidden = true
        photoImageView.accessibilityIdentifier = "aiscan.album.preview"
        photoCard.addSubview(photoImageView)

        emptyIconBackground.translatesAutoresizingMaskIntoConstraints = false
        emptyIconBackground.backgroundColor = .clear
        emptyIconBackgroundLayer.name = "aiscan.album.empty-icon-background"
        emptyIconBackgroundLayer.fillColor = AIScanReferenceTheme.disabledSurface.cgColor
        emptyIconBackground.layer.insertSublayer(emptyIconBackgroundLayer, at: 0)
        let icon = UIImageView(image: UIImage(
            named: "vuesaxBoldGalleryRemove",
            in: AIScanCameraResourceBundle.bundle,
            compatibleWith: nil
        ))
        icon.translatesAutoresizingMaskIntoConstraints = false
        emptyIconBackground.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            icon.centerXAnchor.constraint(equalTo: emptyIconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: emptyIconBackground.centerYAnchor),
            emptyIconBackground.widthAnchor.constraint(equalToConstant: 86),
            emptyIconBackground.heightAnchor.constraint(equalToConstant: 86),
        ])

        let emptyLabel = UILabel()
        emptyLabel.text = AIScanCameraStrings.localizedMessageKey("album.empty")
        emptyLabel.textColor = AIScanReferenceTheme.textTertiary
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.textAlignment = .center
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        emptyStack.axis = .vertical
        emptyStack.alignment = .center
        emptyStack.spacing = 14
        emptyStack.addArrangedSubview(emptyIconBackground)
        emptyStack.addArrangedSubview(emptyLabel)
        photoCard.addSubview(emptyStack)

        NSLayoutConstraint.activate([
            photoImageView.topAnchor.constraint(equalTo: photoCard.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: photoCard.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: photoCard.trailingAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: photoCard.bottomAnchor),
            emptyStack.centerXAnchor.constraint(equalTo: photoCard.centerXAnchor),
            emptyStack.centerYAnchor.constraint(equalTo: photoCard.centerYAnchor),
        ])
        photoBorderLayer.name = "aiscan.album.photo-border"
        photoBorderLayer.fillColor = UIColor.clear.cgColor
        photoBorderLayer.lineWidth = 1
        photoCard.layer.addSublayer(photoBorderLayer)
    }

    private func buildValidationRow() {
        let icon = UIImageView(image: UIImage(
            systemName: "exclamationmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)
        ))
        icon.tintColor = AIScanReferenceTheme.warning
        icon.setContentHuggingPriority(.required, for: .horizontal)
        validationLabel.font = .systemFont(ofSize: 17, weight: .bold)
        validationLabel.textColor = AIScanReferenceTheme.warning
        validationLabel.numberOfLines = 0
        validationRow.axis = .horizontal
        validationRow.alignment = .top
        validationRow.spacing = 6
        validationRow.addArrangedSubview(icon)
        validationRow.addArrangedSubview(validationLabel)
        validationRow.isHidden = true
        validationRow.accessibilityIdentifier = "aiscan.album.validation"
    }

    private func updateSelectionUI() {
        for (position, button) in areaButtons {
            let selected = position == selectedPosition
            button.backgroundColor = selected
                ? AIScanReferenceTheme.brandPrimary
                : AIScanReferenceTheme.brandTint
            button.setTitleColor(
                selected ? AIScanReferenceTheme.onBrand : AIScanReferenceTheme.albumUnselectedAction,
                for: .normal
            )
        }
        photoImageView.image = selectedImage
        photoImageView.isHidden = selectedImage == nil
        emptyStack.isHidden = selectedImage != nil
        analyzeButton.isEnabled = selectedImage != nil && !isAnalyzing
        updateAnalyzeButtonStyle()
    }

    private func updateAnalyzeButtonStyle() {
        let hasSelectedImage = selectedImage != nil
        analyzeBackgroundLayer.fillColor = AIScanReferenceTheme.resolvedCGColor(
            hasSelectedImage ? AIScanReferenceTheme.brandPrimary : AIScanReferenceTheme.disabledSurface,
            traits: traitCollection
        )
        analyzeLabel.textColor = hasSelectedImage
            ? AIScanReferenceTheme.onBrand
            : AIScanReferenceTheme.textTertiary
    }

    private func updateLayerColors() {
        photoBorderLayer.strokeColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.controlBorder,
            traits: traitCollection
        )
        dashedBorderLayer.strokeColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.controlBorder,
            traits: traitCollection
        )
        emptyIconBackgroundLayer.fillColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.disabledSurface,
            traits: traitCollection
        )
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func areaTapped(_ sender: UIButton) {
        selectedPosition = areaButtons.first(where: { $0.value === sender })?.key
        updateSelectionUI()
    }

    @objc private func selectPhotoTapped() {
        if #available(iOS 14, *) {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .current
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            present(picker, animated: true)
        }
    }

    @objc private func analyzeTapped() {
        guard let selectedImage, analyzeButton.isEnabled else { return }
        setValidationMessage(nil)
        setAnalyzing(true)
        onAnalyze?(selectedImage, selectedPosition)
    }

    private func applySelectedImage(_ image: UIImage) {
        selectedImage = image
        isAnalyzing = false
        setValidationMessage(nil)
        updateSelectionUI()
    }

    private static func canonicalPosition(_ position: String?) -> String? {
        switch position?.lowercased() {
        case "ear": "ear"
        case "belly", "body": "belly"
        case "foot", "paw", "paws": "foot"
        default: nil
        }
    }
}

@available(iOS 14, *)
extension AIScanAlbumSelectionViewController: @preconcurrency PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let provider = results.first?.itemProvider else {
            picker.dismiss(animated: true)
            return
        }
        AIScanAlbumImageLoader.loadFullResolutionImage(from: provider) { [weak self, weak picker] image in
            guard let image else {
                picker?.dismiss(animated: true)
                return
            }
            picker?.dismiss(animated: true)
            self?.applySelectedImage(image)
        }
    }
}

extension AIScanAlbumSelectionViewController: @preconcurrency UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true)
        if let image { applySelectedImage(image) }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

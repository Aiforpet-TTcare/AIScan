import PhotosUI
import UIKit
import UniformTypeIdentifiers
import AIScanCore

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
        loadPhoto(from: provider) { completion($0?.image) }
    }

    nonisolated static func loadPhoto(
        from provider: NSItemProvider,
        completion: @escaping @MainActor @Sendable (AIScanAlbumPhoto?) -> Void
    ) {
        let imageType = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .image) == true
        } ?? UTType.image.identifier

        let providerBox = ItemProviderBox(provider)
        provider.loadFileRepresentation(forTypeIdentifier: imageType) { url, _ in
            if let url,
               let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let photo = AIScanAlbumPhoto(data: data) {
                Task { @MainActor in completion(photo) }
                return
            }

            let provider = providerBox.value
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                Task { @MainActor in completion(nil) }
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                let photo = image.map { AIScanAlbumPhoto(image: $0) }
                Task { @MainActor in completion(photo) }
            }
        }
    }
}

@MainActor
final class AIScanAlbumSelectionViewController: UIViewController {
    var onClose: (() -> Void)?
    var onAnalyze: ((UIImage, String?) -> Void)?
    var onValidatedPhoto: ((UIImage, String?) -> Void)? {
        didSet { if isViewLoaded { updateSelectionUI() } }
    }
    var onInspect: ((AIScanAlbumPhoto, @escaping (AIScanAlbumQualityReport) -> Void) -> Void)?
    private(set) var qualityReport: AIScanAlbumQualityReport?
    private(set) var selectedPhoto: AIScanAlbumPhoto?

    private let allowsPositionSelection: Bool
    private var selectedPosition: String?
    private var selectedImage: UIImage?
    private let partType: AISCPartType
    private let inspectionStatusLabel = UILabel()
    private let inspectionStatusRow = UIStackView()
    private let inspectionSpinner = UIActivityIndicatorView(style: .medium)
    private var inspectionGeneration = 0
    private var isInspecting = false
    private var isClosed = false
    private let contentStack = UIStackView()
    private let contentScrollView = UIScrollView()
    private var contentBottomConstraint: NSLayoutConstraint?
    private let areaStack = UIStackView()
    private let photoCard = UIView()
    private var photoHeightConstraint: NSLayoutConstraint?
    private let photoImageView = UIImageView()
    private let emptyStack = UIStackView()
    private let emptyIconBackground = UIView()
    private let emptyIconBackgroundLayer = CAShapeLayer()
    private let validationRow = UIStackView()
    private let validationLabel = UILabel()
    private let inspectionRetryButton = UIButton(type: .system)
    private let selectPhotoButton = UIButton(type: .system)
    private let dashedBorderLayer = CAShapeLayer()
    private let analyzeButton = UIButton(type: .system)
    private let analyzeBackgroundLayer = CAShapeLayer()
    private let analyzeLabel = UILabel()
    private var areaButtons: [String: UIButton] = [:]
    private var isAnalyzing = false

    init(allowsPositionSelection: Bool, initialPosition: String?, partType: AISCPartType? = nil) {
        self.allowsPositionSelection = allowsPositionSelection
        self.partType = partType ?? (allowsPositionSelection ? .skin : .eye)
        selectedPosition = Self.canonicalPosition(initialPosition)
            ?? (allowsPositionSelection ? "belly" : initialPosition)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = AIScanReferenceTheme.photoBackground
        buildHeader()
        buildContent()
        updateSelectionUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreviewHeight()
        if selectPhotoButton.bounds.width.isFinite,
           selectPhotoButton.bounds.height.isFinite,
           selectPhotoButton.bounds.width > 1,
           selectPhotoButton.bounds.height > 1 {
            dashedBorderLayer.frame = selectPhotoButton.bounds
            let dashedBounds = selectPhotoButton.bounds.insetBy(dx: 0.5, dy: 0.5)
            dashedBorderLayer.path = UIBezierPath(
                roundedRect: dashedBounds,
                cornerRadius: 15.5
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
                cornerRadius: 18
            ).cgPath
        }
        analyzeButton.layer.cornerRadius = 18
        analyzeButton.layer.borderWidth = analyzeButton.isEnabled ? 0 : 1
        analyzeButton.layer.borderColor = AIScanReferenceTheme.photoSecondaryText.cgColor
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
            paragraph.lineBreakMode = .byWordWrapping
            if #available(iOS 14.0, *) { paragraph.lineBreakStrategy = .hangulWordPriority }
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
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentScrollView)
        contentScrollView.addSubview(contentStack)
        let bottom = contentScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -88)
        contentBottomConstraint = bottom
        NSLayoutConstraint.activate([
            contentScrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom,
            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor, constant: -40),
            contentStack.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.frameLayoutGuide.heightAnchor, constant: -36),
        ])
    }

    private func buildContent() {
        if allowsPositionSelection {
            buildAreaSelector()
            contentStack.addArrangedSubview(areaStack)
            contentStack.setCustomSpacing(19, after: areaStack)
        }

        selectPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        selectPhotoButton.layer.cornerRadius = 16
        selectPhotoButton.backgroundColor = AIScanReferenceTheme.photoSurface
        selectPhotoButton.accessibilityIdentifier = "aiscan.album.select-photo"
        selectPhotoButton.accessibilityLabel = AIScanCameraStrings.localizedMessageKey("album.select_photo")
        selectPhotoButton.addTarget(self, action: #selector(selectPhotoTapped), for: .touchUpInside)
        selectPhotoButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        let selectIcon = UIImageView(image: UIImage(
            systemName: "circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17)
        ))
        selectIcon.tintColor = AIScanReferenceTheme.photoPrimary
        selectIcon.setContentHuggingPriority(.required, for: .horizontal)
        let selectLabel = UILabel()
        selectLabel.text = AIScanCameraStrings.localizedMessageKey("album.select_photo")
        selectLabel.textColor = AIScanReferenceTheme.photoPrimary
        selectLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        selectLabel.accessibilityIdentifier = "aiscan.album.select-photo.label"
        let selectContent = UIStackView(arrangedSubviews: [selectIcon, selectLabel])
        selectContent.translatesAutoresizingMaskIntoConstraints = false
        selectContent.axis = .horizontal
        selectContent.alignment = .center
        selectContent.spacing = 12
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
        photoHeightConstraint = photoHeight
        photoHeight.isActive = true

        buildValidationRow()
        contentStack.addArrangedSubview(validationRow)

        inspectionRetryButton.setTitle(AIScanCameraStrings.localized(.retry), for: .normal)
        inspectionRetryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        inspectionRetryButton.backgroundColor = AIScanReferenceTheme.brandTint
        inspectionRetryButton.setTitleColor(AIScanReferenceTheme.albumUnselectedAction, for: .normal)
        inspectionRetryButton.layer.cornerRadius = 12
        inspectionRetryButton.accessibilityIdentifier = "aiscan.album.retry-inspection"
        inspectionRetryButton.addTarget(self, action: #selector(retryInspectionTapped), for: .touchUpInside)
        inspectionRetryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        inspectionRetryButton.isHidden = true
        contentStack.addArrangedSubview(inspectionRetryButton)

        inspectionStatusLabel.text = AIScanCameraStrings.localizedMessageKey("album.quality.checking")
        inspectionStatusLabel.font = .systemFont(ofSize: 16)
        inspectionStatusLabel.textColor = AIScanReferenceTheme.textSecondary
        inspectionStatusLabel.numberOfLines = 0
        inspectionStatusLabel.accessibilityIdentifier = "aiscan.album.checking"
        inspectionStatusLabel.isHidden = true
        inspectionSpinner.color = AIScanReferenceTheme.photoPrimary
        inspectionSpinner.hidesWhenStopped = true
        inspectionStatusRow.axis = .horizontal
        inspectionStatusRow.alignment = .center
        inspectionStatusRow.spacing = 10
        inspectionStatusRow.addArrangedSubview(inspectionSpinner)
        inspectionStatusRow.addArrangedSubview(inspectionStatusLabel)
        contentStack.addArrangedSubview(inspectionStatusRow)

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
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(analyzeButton)
        NSLayoutConstraint.activate([
            analyzeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            analyzeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            analyzeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
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
        photoCard.backgroundColor = AIScanReferenceTheme.photoSurface
        photoCard.layer.cornerRadius = 16
        photoCard.layer.borderWidth = 1
        photoCard.clipsToBounds = false
        photoCard.accessibilityIdentifier = "aiscan.album.photo-card"
        photoCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectPhotoTapped)))

        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = 16
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
        emptyLabel.textColor = AIScanReferenceTheme.photoSecondaryText
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
        validationLabel.accessibilityIdentifier = "aiscan.album.validation.message"
        validationRow.axis = .horizontal
        validationLabel.textAlignment = .center
        validationRow.alignment = .center
        validationRow.spacing = 6
        validationRow.addArrangedSubview(validationLabel)
        validationRow.isHidden = true
        validationRow.accessibilityIdentifier = "aiscan.album.validation"
    }

    private func updateSelectionUI() {
        let isCollecting = onValidatedPhoto != nil
        analyzeButton.isHidden = isCollecting
        contentBottomConstraint?.constant = isCollecting ? -16 : -88
        let canSelect = !isInspecting && !isAnalyzing && !isClosed
        selectPhotoButton.isEnabled = canSelect
        selectPhotoButton.alpha = canSelect ? 1 : 0.45
        photoCard.isUserInteractionEnabled = canSelect
        for (position, button) in areaButtons {
            button.isEnabled = canSelect
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
        inspectionRetryButton.isHidden = qualityReport?.inspectionError == nil || isInspecting || isAnalyzing || isClosed
        inspectionStatusLabel.isHidden = !isInspecting || isAnalyzing || isClosed
        inspectionStatusRow.isHidden = inspectionStatusLabel.isHidden
        if inspectionStatusRow.isHidden { inspectionSpinner.stopAnimating() }
        else { inspectionSpinner.startAnimating() }
        updatePreviewHeight()
        analyzeButton.isEnabled = !isCollecting && qualityReport?.isValid == true && !isAnalyzing && !isInspecting && !isClosed
        updateAnalyzeButtonStyle()
    }

    private func updatePreviewHeight() {
        let height = min(380, max(160, view.bounds.height * 0.6))
        if photoHeightConstraint?.constant != height { photoHeightConstraint?.constant = height }
    }

    private func updateAnalyzeButtonStyle() {
        let hasSelectedImage = qualityReport?.isValid == true && !isInspecting && !isClosed
        analyzeBackgroundLayer.fillColor = AIScanReferenceTheme.resolvedCGColor(
            hasSelectedImage ? AIScanReferenceTheme.photoPrimary : AIScanReferenceTheme.photoAction,
            traits: traitCollection
        )
        analyzeLabel.textColor = hasSelectedImage
            ? AIScanReferenceTheme.photoBackground
            : AIScanReferenceTheme.photoSecondaryText
    }

    private func updateLayerColors() {
        photoCard.layer.borderColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.photoBorder,
            traits: traitCollection
        )
        dashedBorderLayer.strokeColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.photoBorder,
            traits: traitCollection
        )
        emptyIconBackgroundLayer.fillColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.disabledSurface,
            traits: traitCollection
        )
    }

    @objc private func closeTapped() {
        isClosed = true
        inspectionGeneration += 1
        updateSelectionUI()
        onClose?()
    }

    @objc private func areaTapped(_ sender: UIButton) {
        guard !isInspecting, !isAnalyzing, !isClosed else { return }
        selectedPosition = areaButtons.first(where: { $0.value === sender })?.key
        updateSelectionUI()
    }

    @objc private func selectPhotoTapped() {
        guard !isInspecting, !isAnalyzing, !isClosed, presentedViewController == nil else { return }
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
        guard let selectedImage, analyzeButton.isEnabled, qualityReport?.isValid == true else { return }
        setValidationMessage(nil)
        setAnalyzing(true)
        onAnalyze?(selectedImage, selectedPosition)
    }

    @objc private func retryInspectionTapped() {
        guard let selectedPhoto, qualityReport?.inspectionError != nil,
              !isInspecting, !isAnalyzing, !isClosed else { return }
        applySelectedPhoto(selectedPhoto)
    }

    func applySelectedPhoto(_ photo: AIScanAlbumPhoto) {
        inspectionGeneration += 1
        let generation = inspectionGeneration
        selectedPhoto = photo
        selectedImage = photo.image
        let report = AIScanAlbumQualityReport(metadata: photo.metadata, part: partType)
        qualityReport = report
        isAnalyzing = false
        isInspecting = report.originalIsValid && report.requiresDetection
        setValidationMessage(nil)
        renderQuality()
        updateSelectionUI()
        guard isInspecting else { approvePhotoForCollectionIfNeeded(); return }
        guard let onInspect else {
            finishInspection(report.measured(nil, issue: "detect"), generation: generation)
            return
        }
        onInspect(photo) { [weak self] result in
            self?.finishInspection(result, generation: generation)
        }
    }

    private func finishInspection(_ report: AIScanAlbumQualityReport, generation: Int) {
        guard generation == inspectionGeneration, !isClosed else { return }
        qualityReport = report
        isInspecting = false
        renderQuality()
        updateSelectionUI()
        approvePhotoForCollectionIfNeeded()
    }

    private func approvePhotoForCollectionIfNeeded() {
        guard let onValidatedPhoto, let selectedImage,
              qualityReport?.isValid == true, !isInspecting, !isAnalyzing, !isClosed else { return }
        setAnalyzing(true)
        onValidatedPhoto(selectedImage, selectedPosition)
    }

    private func beginLoadingPhoto() -> Int {
        inspectionGeneration += 1
        isInspecting = true
        qualityReport = nil
        selectedPhoto = nil
        selectedImage = nil
        renderQuality()
        updateSelectionUI()
        return inspectionGeneration
    }

    private func renderQuality() {
        guard let report = qualityReport else {
            setValidationMessage(nil)
            return
        }
        setValidationMessage(AIScanCameraStrings.albumQualityFailureMessage(
            for: report, isInspecting: isInspecting, analysisPosition: selectedPosition
        ))
    }

    private func dismissPhotoPicker(_ picker: UIViewController, completion: @escaping () -> Void) {
        guard picker.presentingViewController != nil else { completion(); return }
        picker.dismiss(animated: true, completion: completion)
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
        let generation = beginLoadingPhoto()
        // Dismiss the system list before reading the original asset. iCloud
        // loading can be slow; progress belongs on our album screen. Waiting
        // for dismissal also prevents collection from presenting during it.
        dismissPhotoPicker(picker) { [weak self] in
            guard let self, generation == self.inspectionGeneration, !self.isClosed else { return }
            AIScanAlbumImageLoader.loadPhoto(from: provider) { [weak self] photo in
                guard let self, generation == self.inspectionGeneration, !self.isClosed else { return }
                guard let photo else {
                    self.isInspecting = false
                    self.updateSelectionUI()
                    self.setValidationMessage(AIScanCameraStrings.localizedMessageKey("album.quality.load_failed"))
                    return
                }
                self.applySelectedPhoto(photo)
            }
        }
    }
}

extension AIScanAlbumSelectionViewController: @preconcurrency UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let generation = beginLoadingPhoto()
        dismissPhotoPicker(picker) { [weak self] in
            guard let self, generation == self.inspectionGeneration, !self.isClosed else { return }
            if let url = info[.imageURL] as? URL,
               let data = try? Data(contentsOf: url), let photo = AIScanAlbumPhoto(data: data) {
                self.applySelectedPhoto(photo)
            } else if let image = info[.originalImage] as? UIImage {
                self.applySelectedPhoto(AIScanAlbumPhoto(image: image))
            } else {
                self.isInspecting = false
                self.updateSelectionUI()
                self.setValidationMessage(AIScanCameraStrings.localizedMessageKey("album.quality.load_failed"))
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

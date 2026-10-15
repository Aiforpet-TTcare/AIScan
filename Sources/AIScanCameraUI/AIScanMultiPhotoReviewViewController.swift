import UIKit

@MainActor
final class AIScanMultiPhotoReviewViewController: UIViewController {
    var onCamera: (() -> Void)?
    var onAlbum: (() -> Void)?
    var onAnalyze: (() -> Void)?
    var onBack: (() -> Void)?
    var onRemove: ((String) -> Void)?
    private let allowsAlbum: Bool
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let grid = UIStackView()
    private let analyzeButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)
    private let albumButton = UIButton(type: .system)
    private let addActions = UIStackView()
    private var items: [AIScanMultiPhotoJob] = []

    init(allowsAlbum: Bool) {
        self.allowsAlbum = allowsAlbum
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = AIScanReferenceTheme.photoBackground
        view.accessibilityIdentifier = "aiscan.multi.review"
        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = AIScanReferenceTheme.photoPrimary
        back.accessibilityLabel = AIScanCameraStrings.localizedMessageKey("multi.add_more")
        back.accessibilityIdentifier = "aiscan.multi.back"
        back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        back.widthAnchor.constraint(equalToConstant: 44).isActive = true
        back.heightAnchor.constraint(equalToConstant: 44).isActive = true
        titleLabel.text = AIScanCameraStrings.localizedMessageKey("multi.review")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = AIScanReferenceTheme.photoPrimary
        let header = UIStackView(arrangedSubviews: [back, titleLabel, UIView()])
        header.alignment = .center; header.spacing = 8
        let heading = UILabel()
        heading.text = AIScanCameraStrings.localizedMessageKey("multi.check_photos")
        heading.font = .systemFont(ofSize: 24, weight: .bold)
        heading.textColor = AIScanReferenceTheme.photoPrimary
        heading.numberOfLines = 0
        countLabel.font = .systemFont(ofSize: 16)
        countLabel.textColor = AIScanReferenceTheme.photoSecondaryText
        countLabel.accessibilityIdentifier = "aiscan.multi.count"
        let guidance = UILabel()
        guidance.text = AIScanCameraStrings.localizedMessageKey("multi.guidance")
        guidance.font = .systemFont(ofSize: 14)
        guidance.textColor = AIScanReferenceTheme.photoSecondaryText
        guidance.numberOfLines = 0
        grid.axis = .vertical; grid.spacing = 28
        let contents = UIStackView(arrangedSubviews: [heading, countLabel, guidance, grid])
        contents.axis = .vertical; contents.spacing = 16
        contents.setCustomSpacing(28, after: guidance)
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.addSubview(contents)
        style(analyzeButton, primary: true)
        style(addButton, primary: false)
        style(albumButton, primary: false)
        analyzeButton.accessibilityIdentifier = "aiscan.multi.analyze"
        addButton.accessibilityIdentifier = "aiscan.multi.add"
        analyzeButton.addTarget(self, action: #selector(analyzeTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        albumButton.addTarget(self, action: #selector(albumTapped), for: .touchUpInside)
        albumButton.accessibilityIdentifier = "aiscan.multi.album"
        albumButton.setTitle(AIScanCameraStrings.localizedMessageKey("multi.album"), for: .normal)
        albumButton.isHidden = !allowsAlbum
        addButton.setTitle(AIScanCameraStrings.localizedMessageKey("multi.add_more"), for: .normal)
        addActions.axis = .horizontal; addActions.spacing = 12; addActions.distribution = .fillEqually
        addActions.addArrangedSubview(addButton); addActions.addArrangedSubview(albumButton)
        let actions = UIStackView(arrangedSubviews: [analyzeButton, addActions])
        actions.axis = .vertical; actions.spacing = 10
        [header, scroll, actions].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        contents.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -16),
            contents.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            contents.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            contents.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            contents.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            contents.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            actions.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actions.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actions.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        refresh(items)
    }

    func refresh(_ items: [AIScanMultiPhotoJob]) {
        self.items = items
        guard isViewLoaded else { return }
        countLabel.text = String(format: AIScanCameraStrings.localizedMessageKey("multi.count"), items.count)
        analyzeButton.setTitle(String(format: AIScanCameraStrings.localizedMessageKey("multi.results"), items.count), for: .normal)
        analyzeButton.isEnabled = !items.isEmpty
        analyzeButton.alpha = items.isEmpty ? 0.45 : 1
        addButton.isHidden = items.count >= 4
        albumButton.isHidden = !allowsAlbum || items.count >= 4
        addActions.isHidden = items.count >= 4
        grid.arrangedSubviews.forEach { grid.removeArrangedSubview($0); $0.removeFromSuperview() }
        for row in 0..<2 {
            let columns = UIStackView()
            columns.axis = .horizontal; columns.spacing = 12; columns.distribution = .fillEqually
            columns.alignment = .top
            for column in 0..<2 {
                let index = row * 2 + column
                columns.addArrangedSubview(card(index < items.count ? items[index] : nil, index: index))
            }
            grid.addArrangedSubview(columns)
        }
    }

    private func card(_ item: AIScanMultiPhotoJob?, index: Int) -> UIView {
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 8
        let photo = UIButton(type: .system)
        photo.backgroundColor = AIScanReferenceTheme.photoSurface
        photo.layer.cornerRadius = 18; photo.clipsToBounds = true
        photo.accessibilityIdentifier = "aiscan.multi.photo.\(index + 1)"
        photo.heightAnchor.constraint(equalTo: photo.widthAnchor).isActive = true
        photo.layer.borderWidth = 1
        photo.layer.borderColor = AIScanReferenceTheme.photoBorder.cgColor
        if let item {
            let image = UIImageView(image: item.preview)
            image.contentMode = .scaleAspectFill; image.clipsToBounds = true
            image.translatesAutoresizingMaskIntoConstraints = false
            photo.addSubview(image)
            NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo: photo.leadingAnchor), image.trailingAnchor.constraint(equalTo: photo.trailingAnchor), image.topAnchor.constraint(equalTo: photo.topAnchor), image.bottomAnchor.constraint(equalTo: photo.bottomAnchor)])
            photo.layer.borderWidth = 1
            photo.layer.borderColor = AIScanReferenceTheme.photoBorder.cgColor
        } else {
            let iconBackground = UIView()
            iconBackground.backgroundColor = AIScanReferenceTheme.photoAction
            iconBackground.layer.cornerRadius = 23
            let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
            icon.tintColor = AIScanReferenceTheme.photoPrimary
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            iconBackground.addSubview(icon)
            let placeholderCaption = UILabel()
            placeholderCaption.text = String(format: AIScanCameraStrings.localizedMessageKey("multi.photo"), index + 1)
            placeholderCaption.font = .systemFont(ofSize: 14)
            placeholderCaption.textColor = AIScanReferenceTheme.photoSecondaryText
            let placeholder = UIStackView(arrangedSubviews: [iconBackground, placeholderCaption])
            placeholder.axis = .vertical; placeholder.alignment = .center; placeholder.spacing = 12
            placeholder.isUserInteractionEnabled = false
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            photo.addSubview(placeholder)
            NSLayoutConstraint.activate([
                placeholder.centerXAnchor.constraint(equalTo: photo.centerXAnchor),
                placeholder.centerYAnchor.constraint(equalTo: photo.centerYAnchor),
                iconBackground.widthAnchor.constraint(equalToConstant: 46),
                iconBackground.heightAnchor.constraint(equalToConstant: 46),
                icon.widthAnchor.constraint(equalToConstant: 30),
                icon.heightAnchor.constraint(equalToConstant: 30),
                icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            ])
            photo.accessibilityLabel = AIScanCameraStrings.localizedMessageKey("multi.add_photo")
        }
        photo.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        stack.addArrangedSubview(photo)
        let caption = UILabel()
        caption.text = String(format: AIScanCameraStrings.localizedMessageKey("multi.photo"), index + 1)
        caption.font = .systemFont(ofSize: 15, weight: .semibold)
        caption.textColor = AIScanReferenceTheme.photoPrimary
        let remove = UIButton(type: .system)
        remove.setTitle(AIScanCameraStrings.localizedMessageKey("multi.remove"), for: .normal)
        remove.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        remove.tintColor = AIScanReferenceTheme.photoPrimary
        remove.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        remove.accessibilityIdentifier = "aiscan.multi.remove.\(index + 1)"
        remove.tag = index
        remove.isHidden = item == nil
        remove.addTarget(self, action: #selector(removeTapped(_:)), for: .touchUpInside)
        let line = UIStackView(arrangedSubviews: [caption, UIView(), remove]); line.alignment = .center
        line.isHidden = item == nil
        stack.addArrangedSubview(line)
        let status = UILabel()
        status.font = .systemFont(ofSize: 12)
        status.textColor = item?.outcome == nil ? AIScanReferenceTheme.photoSecondaryText : AIScanReferenceTheme.warning
        status.numberOfLines = 2
        if let item {
            let key = item.phase == .ready ? "multi.ready" : item.outcome == nil ? "multi.preparing" : "multi.upload_failed"
            status.text = AIScanCameraStrings.localizedMessageKey(key)
        }
        status.isHidden = item?.outcome == nil
        stack.addArrangedSubview(status)
        return stack
    }

    private func style(_ button: UIButton, primary: Bool) {
        button.backgroundColor = primary ? AIScanReferenceTheme.photoPrimary : AIScanReferenceTheme.photoAction
        button.setTitleColor(primary ? AIScanReferenceTheme.photoBackground : AIScanReferenceTheme.photoPrimary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.titleLabel?.numberOfLines = 0; button.titleLabel?.textAlignment = .center
        button.layer.cornerRadius = 18
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    }

    @objc private func removeTapped(_ button: UIButton) {
        guard items.indices.contains(button.tag) else { return }
        onRemove?(items[button.tag].id)
    }
    @objc private func analyzeTapped() { if !items.isEmpty { onAnalyze?() } }
    @objc private func backTapped() { onBack?() }
    @objc private func cameraTapped() { onCamera?() }
    @objc private func albumTapped() { if allowsAlbum && items.count < 4 { onAlbum?() } }
}

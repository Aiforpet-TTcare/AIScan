import UIKit

@MainActor
@objc(AIScanResultViewController)
public final class AIScanResultViewController: UIViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var navigationContainer: UIView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var collectionView: UICollectionView!

    public var onClose: (() -> Void)?

    private var viewModel = AIScanDisplayResultViewModel(status: "NORMAL")
    private var selectedIndex = 0
    private var rows: [Row] = []

    private enum Row {
        case status
        case title
        case date
        case tabs
        case item
        case notice
        case spacing(CGFloat)
    }

    public static func instance(
        viewModel: AIScanDisplayResultViewModel,
        onClose: (() -> Void)? = nil
    ) -> AIScanResultViewController {
        let storyboard = UIStoryboard(
            name: "Result",
            bundle: AIScanReferenceStrings.resourceBundle
        )
        guard let controller = storyboard.instantiateViewController(
            identifier: "ResultViewController"
        ) as? AIScanResultViewController else {
            preconditionFailure("AIScanReferenceUI Result.storyboard is missing")
        }
        controller.viewModel = viewModel
        controller.onClose = onClose
        return controller
    }

    public func apply(viewModel: AIScanDisplayResultViewModel) {
        self.viewModel = viewModel
        selectedIndex = min(selectedIndex, max(0, viewModel.symptoms.count - 1))
        rebuildRows()
        guard isViewLoaded else { return }
        configureHeader()
        collectionView.reloadData()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        rebuildRows()
        configureHeader()
        applyTheme()
        view.accessibilityIdentifier = "aiscan.result.root"
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
            collectionView.reloadData()
        }
    }

    @IBAction private func didTapBackButton(_ sender: Any) {
        close()
    }

    @IBAction private func didTapCloseButton(_ sender: Any) {
        close()
    }

    private func close() {
        if let onClose {
            onClose()
        } else if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func configureCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        let bundle = AIScanReferenceStrings.resourceBundle
        let registrations: [(String, String)] = [
            (AIScanResultStatusCell.reuseIdentifier, "ResultStatusCell"),
            (AIScanResultTitleCell.reuseIdentifier, "ResultTitleCell"),
            (AIScanResultDateCell.reuseIdentifier, "ResultDateCell"),
            (AIScanResultTabCell.reuseIdentifier, "ResultTabCell"),
            (AIScanResultItemCell.reuseIdentifier, "ResultItemCell"),
            (AIScanResultNoticeCell.reuseIdentifier, "ResultNoticeCell"),
            (AIScanResultSpaceCell.reuseIdentifier, "SpaceCell")
        ]
        for (identifier, nibName) in registrations {
            collectionView.register(
                UINib(nibName: nibName, bundle: bundle),
                forCellWithReuseIdentifier: identifier
            )
        }
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
        }
    }

    private func configureHeader() {
        titleLabel.text = AIScanReferenceStrings.localized(.resultTitle)
        titleLabel.accessibilityIdentifier = "aiscan.result.navigation-title"
        backButton.accessibilityLabel = AIScanReferenceStrings.localized(.close)
        backButton.accessibilityIdentifier = "aiscan.result.close"
        closeButton.accessibilityLabel = AIScanReferenceStrings.localized(.close)
    }

    private func rebuildRows() {
        rows = [.status, .title, .spacing(13), .date, .spacing(20)]
        if !viewModel.symptoms.isEmpty {
            rows.append(.tabs)
        }
        rows.append(.item)
        rows.append(.notice)
    }

    private var selectedSymptom: AIScanDisplaySymptomViewModel {
        if let symptom = viewModel.symptoms.indices.contains(selectedIndex)
            ? viewModel.symptoms[selectedIndex]
            : viewModel.symptoms.first {
            return symptom
        }
        return AIScanDisplaySymptomViewModel(
            name: AIScanReferenceStrings.localized(.noSymptoms),
            detailRows: [
                AIScanDisplayDetailRowViewModel(
                    text: AIScanReferenceStrings.localized(.noSymptoms),
                    iconName: "vuesaxBoldMessageNotif"
                )
            ]
        )
    }

    private var headline: String {
        if let headline = viewModel.headline, !headline.isEmpty { return headline }
        return switch viewModel.displayStatus {
        case .normal: AIScanReferenceStrings.localized(.normalHeadline)
        case .caution: AIScanReferenceStrings.localized(.cautionHeadline)
        case .warning: AIScanReferenceStrings.localized(.warningHeadline)
        }
    }

    private var analyzedAtText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd HH:mm"
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        return formatter.string(from: viewModel.analyzedAt)
    }

    private func applyTheme() {
        view.backgroundColor = AIScanReferenceTheme.background
        navigationContainer.backgroundColor = AIScanReferenceTheme.background
        collectionView.backgroundColor = AIScanReferenceTheme.background
        titleLabel.textColor = AIScanReferenceTheme.textPrimary
        for button in [backButton, closeButton] {
            let image = button?.image(for: .normal)?.withRenderingMode(.alwaysTemplate)
            button?.setImage(image, for: .normal)
            button?.tintColor = AIScanReferenceTheme.textPrimary
        }
    }
}

extension AIScanResultViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        rows.count
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch rows[indexPath.item] {
        case .status:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AIScanResultStatusCell.reuseIdentifier,
                for: indexPath
            ) as! AIScanResultStatusCell
            cell.parentViewController = self
            cell.configure(status: viewModel.displayStatus)
            cell.accessibilityIdentifier = "aiscan.result.status"
            return cell

        case .title:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AIScanResultTitleCell.reuseIdentifier,
                for: indexPath
            ) as! AIScanResultTitleCell
            cell.configure(title: headline, subtitle: viewModel.subtitle)
            cell.accessibilityIdentifier = "aiscan.result.headline"
            return cell

        case .date:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AIScanResultDateCell.reuseIdentifier,
                for: indexPath
            ) as! AIScanResultDateCell
            cell.configure(text: analyzedAtText)
            cell.accessibilityIdentifier = "aiscan.result.date"
            return cell

        case .tabs:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AIScanResultTabCell.reuseIdentifier,
                for: indexPath
            ) as! AIScanResultTabCell
            cell.configure(items: viewModel.symptoms, selectedIndex: selectedIndex)
            cell.onSelect = { [weak self] index in
                guard let self else { return }
                self.selectedIndex = index
                self.collectionView.reloadItems(at: [
                    indexPath,
                    IndexPath(item: indexPath.item + 1, section: indexPath.section)
                ])
            }
            cell.accessibilityIdentifier = "aiscan.result.symptom-tabs"
            return cell

        case .item:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AIScanResultItemCell.reuseIdentifier,
                for: indexPath
            ) as! AIScanResultItemCell
            cell.delegate = self
            cell.configure(symptom: selectedSymptom)
            cell.accessibilityIdentifier = "aiscan.result.detail"
            return cell

        case .notice:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AIScanResultNoticeCell.reuseIdentifier,
                for: indexPath
            ) as! AIScanResultNoticeCell
            cell.configure(text: viewModel.notice ?? AIScanReferenceStrings.localized(.notice))
            cell.accessibilityIdentifier = "aiscan.result.notice"
            return cell

        case let .spacing(height):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AIScanResultSpaceCell.reuseIdentifier,
                for: indexPath
            ) as! AIScanResultSpaceCell
            cell.height = height
            return cell
        }
    }
}

extension AIScanResultViewController: AIScanResultItemCellDelegate {
    func resultItemCellNeedsResize(_ cell: AIScanResultItemCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        UIView.performWithoutAnimation {
            collectionView.performBatchUpdates({
                collectionView.reloadItems(at: [indexPath])
            })
        }
    }

    func resultItemCell(_ cell: AIScanResultItemCell, didSelectImageURL url: URL) {
        let controller = AIScanResultImageViewController(url: url)
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }
}

private final class AIScanResultImageViewController: UIViewController {
    private let url: URL
    private let imageView = UIImageView()

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        view.addSubview(close)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            close.widthAnchor.constraint(equalToConstant: 44),
            close.heightAnchor.constraint(equalToConstant: 44)
        ])
        AIScanReferenceImageLoader.load(from: url) { [weak self] image in
            self?.imageView.image = image
        }
    }
}

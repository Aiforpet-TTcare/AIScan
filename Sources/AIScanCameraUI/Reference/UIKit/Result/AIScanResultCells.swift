import UIKit
@preconcurrency import AIScanCore

extension UICollectionViewLayoutAttributes {
    var aiscanResultFittedWidth: CGFloat {
        guard size.width > 0 else { return 0 }
        return size.width.nextDown
    }
}

@MainActor
protocol AIScanResultItemCellDelegate: AnyObject {
    func resultItemCell(_ cell: AIScanResultItemCell, didSelectImageURL url: URL)
}

@MainActor
enum AIScanReferenceImageLoader {
    static let cache = NSCache<NSURL, UIImage>()

    static func load(
        from url: URL,
        completion: @MainActor @Sendable @escaping (UIImage?) -> Void
    ) {
        let key = url as NSURL
        if let image = cache.object(forKey: key) {
            completion(image)
            return
        }
        AISCDisplayAssetLoader.loadData(from: url) { data, _ in
            DispatchQueue.main.async {
                let image = data.flatMap(UIImage.init(data:))
                if let image { cache.setObject(image, forKey: key) }
                completion(image)
            }
        }
    }
}

@objc(AIScanResultStatusCell)
@MainActor
final class AIScanResultStatusCell: UICollectionViewCell {
    static let reuseIdentifier = "ResultStatusCell"

    @IBOutlet private weak var container: UIView!
    @IBOutlet private weak var signalContainer: UIView!
    @IBOutlet private weak var signalBackground: UIView!
    @IBOutlet private weak var normalContainer: UIView!
    @IBOutlet private weak var cautionContainer: UIView!
    @IBOutlet private weak var warningContainer: UIView!

    weak var parentViewController: UIViewController?
    private var animationController: AIScanLottiePlayerController?

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { configureAfterNibLoad() }
    }

    private func configureAfterNibLoad() {
        signalContainer.layer.cornerRadius = 43
        signalContainer.layer.masksToBounds = false
        signalContainer.layer.shadowOpacity = 0.15
        signalContainer.layer.shadowOffset = .zero
        signalContainer.layer.shadowRadius = 12
        signalBackground.layer.cornerRadius = 35
        normalContainer.layer.cornerRadius = 28
        cautionContainer.layer.cornerRadius = 28
        warningContainer.layer.cornerRadius = 28
        applyTheme()
    }

    func configure(status: AIScanDisplayStatus) {
        let target: UIView
        let animation: AIScanResultLottie
        switch status {
        case .normal:
            target = normalContainer
            animation = .normal
        case .caution:
            target = cautionContainer
            animation = .caution
        case .cautionQuestionnaire:
            target = cautionContainer
            animation = .caution
        case .warning:
            target = warningContainer
            animation = .warning
        }
        show(animation, in: target)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        removeAnimation()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
        }
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes.size = CGSize(width: layoutAttributes.aiscanResultFittedWidth, height: 130)
        return layoutAttributes
    }

    private func applyTheme() {
        backgroundColor = AIScanReferenceTheme.background
        contentView.backgroundColor = AIScanReferenceTheme.background
        container.backgroundColor = AIScanReferenceTheme.background
        signalContainer.backgroundColor = AIScanReferenceTheme.surface
        signalContainer.layer.shadowColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.shadow,
            traits: traitCollection
        )
    }

    private func show(_ animation: AIScanResultLottie, in target: UIView) {
        removeAnimation()
        guard let parentViewController else { return }
        let controller = AIScanLottiePlayerController.instance(lottie: animation)
        parentViewController.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        target.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: target.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: target.bottomAnchor)
        ])
        controller.didMove(toParent: parentViewController)
        animationController = controller
    }

    private func removeAnimation() {
        animationController?.willMove(toParent: nil)
        animationController?.view.removeFromSuperview()
        animationController?.removeFromParent()
        animationController = nil
    }
}

@objc(AIScanResultTitleCell)
@MainActor
final class AIScanResultTitleCell: UICollectionViewCell {
    static let reuseIdentifier = "ResultTitleCell"

    @IBOutlet private weak var container: UIView!
    @IBOutlet private weak var titleLabel: UILabel!

    private let subtitleLabel = UILabel()
    private var didInstallStack = false

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { configureAfterNibLoad() }
    }

    private func configureAfterNibLoad() {
        installStackIfNeeded()
        applyTheme()
    }

    func configure(title: String, subtitle: String?, emphasizesSubtitle: Bool = false) {
        installStackIfNeeded()
        titleLabel.text = title
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineHeightMultiple = 1.2
        titleLabel.attributedText = NSAttributedString(
            string: title,
            attributes: [
                .font: titleLabel.font as Any,
                .foregroundColor: AIScanReferenceTheme.textPrimary,
                .paragraphStyle: paragraph,
            ]
        )
        subtitleLabel.text = subtitle
        subtitleLabel.font = emphasizesSubtitle
            ? .boldSystemFont(ofSize: 14)
            : .systemFont(ofSize: 14)
        subtitleLabel.isHidden = subtitle?.isEmpty != false
        applyTheme()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
        }
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()
        let target = CGSize(
            width: layoutAttributes.aiscanResultFittedWidth,
            height: UIView.layoutFittingCompressedSize.height
        )
        let size = contentView.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        layoutAttributes.size = CGSize(width: target.width, height: ceil(size.height))
        return layoutAttributes
    }

    private func installStackIfNeeded() {
        guard !didInstallStack else { return }
        didInstallStack = true
        titleLabel.removeFromSuperview()
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.font = .systemFont(ofSize: 14)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            subtitleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func applyTheme() {
        backgroundColor = AIScanReferenceTheme.background
        contentView.backgroundColor = AIScanReferenceTheme.background
        container.backgroundColor = AIScanReferenceTheme.background
        titleLabel.textColor = AIScanReferenceTheme.textPrimary
        subtitleLabel.textColor = AIScanReferenceTheme.textPrimary
    }
}

@objc(AIScanResultDateCell)
@MainActor
final class AIScanResultDateCell: UICollectionViewCell {
    static let reuseIdentifier = "ResultDateCell"

    @IBOutlet private weak var container: UIView!
    @IBOutlet private weak var titleLabel: UILabel!

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { configureAfterNibLoad() }
    }

    private func configureAfterNibLoad() {
        container.layer.cornerRadius = 17
        container.layer.masksToBounds = true
        container.layer.borderWidth = 1
        applyTheme()
    }

    func configure(text: String) {
        titleLabel.text = text
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
        }
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes.size = CGSize(width: layoutAttributes.aiscanResultFittedWidth, height: 34)
        return layoutAttributes
    }

    private func applyTheme() {
        backgroundColor = AIScanReferenceTheme.background
        contentView.backgroundColor = AIScanReferenceTheme.background
        container.backgroundColor = AIScanReferenceTheme.surface
        titleLabel.textColor = AIScanReferenceTheme.dateText
        container.layer.borderColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.divider,
            traits: traitCollection
        )
    }
}

@objc(AIScanResultTabCell)
@MainActor
final class AIScanResultTabCell: UICollectionViewCell, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    static let reuseIdentifier = "ResultTabCell"

    @IBOutlet private weak var container: UIView!

    var onSelect: ((Int) -> Void)?
    private var items: [AIScanDisplaySymptomViewModel] = []
    private let fallbackItems = (0..<5).map { "Item \($0)" }
    private var isConfigured = false
    private var selectedIndex = 0
    private let baseHeight: CGFloat = 40
    private let horizontalPadding: CGFloat = 24
    private let sidePadding: CGFloat = 25
    private let minimumWidth: CGFloat = 60
    private let spacing: CGFloat = 12

    private lazy var layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.dataSource = self
        view.delegate = self
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "tab")
        return view
    }()

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { configureAfterNibLoad() }
    }

    private func configureAfterNibLoad() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: container.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        applyTheme()
    }

    func configure(items: [AIScanDisplaySymptomViewModel], selectedIndex: Int) {
        isConfigured = true
        self.items = items
        self.selectedIndex = min(max(0, selectedIndex), max(0, items.count - 1))
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        if !items.isEmpty {
            collectionView.scrollToItem(
                at: IndexPath(item: self.selectedIndex, section: 0),
                at: .centeredHorizontally,
                animated: false
            )
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
            collectionView.reloadData()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        items = []
        isConfigured = false
        selectedIndex = 0
        collectionView.setContentOffset(.zero, animated: false)
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes.size = CGSize(width: layoutAttributes.aiscanResultFittedWidth, height: 50)
        return layoutAttributes
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        isConfigured ? items.count : fallbackItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tab", for: indexPath)
        let label: UILabel
        if let existing = cell.contentView.viewWithTag(1001) as? UILabel {
            label = existing
        } else {
            label = UILabel()
            label.tag = 1001
            label.textAlignment = .center
            label.layer.cornerRadius = 13
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 13),
                label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
            ])
        }
        let item = isConfigured ? items[indexPath.item] : nil
        label.text = item?.name ?? item?.resultLabel ?? item?.code ?? fallbackItems[indexPath.item]
        let isSelected = isConfigured && indexPath.item == selectedIndex
        applyAppearance(label, selected: isSelected)
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = label.text
        cell.accessibilityIdentifier = item.map { "aiscan.result.symptom.\($0.id)" }
        cell.accessibilityTraits = isSelected ? [.button, .selected] : [.button]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.item
        collectionView.reloadData()
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        onSelect?(selectedIndex)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard isConfigured else {
            return CGSize(width: 120, height: baseHeight)
        }
        let text = items[indexPath.item].name ?? items[indexPath.item].resultLabel ?? items[indexPath.item].code ?? "-"
        let width = text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium)]).width
        return CGSize(width: ceil(max(minimumWidth, width + horizontalPadding)), height: baseHeight)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        let count = self.collectionView(collectionView, numberOfItemsInSection: section)
        let widths = (0..<count).reduce(CGFloat.zero) { result, index in
            result + self.collectionView(
                collectionView,
                layout: collectionViewLayout,
                sizeForItemAt: IndexPath(item: index, section: section)
            ).width
        }
        let contentWidth = widths + CGFloat(max(0, count - 1)) * spacing
        let centeredInset = (collectionView.bounds.width - contentWidth) / 2
        let inset = max(sidePadding, centeredInset)
        return UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
    }

    private func applyTheme() {
        backgroundColor = AIScanReferenceTheme.background
        contentView.backgroundColor = AIScanReferenceTheme.background
        container.backgroundColor = AIScanReferenceTheme.background
    }

    private func applyAppearance(_ label: UILabel, selected: Bool) {
        label.backgroundColor = selected ? AIScanReferenceTheme.brandAccent : AIScanReferenceTheme.surfaceSecondary
        label.textColor = selected ? AIScanReferenceTheme.onBrand : AIScanReferenceTheme.textSecondary
        label.font = selected ? .systemFont(ofSize: 13, weight: .bold) : .systemFont(ofSize: 13)
    }
}

@objc(AIScanResultItemCell)
@MainActor
final class AIScanResultItemCell: UICollectionViewCell {
    static let reuseIdentifier = "ResultItemCell"

    @IBOutlet private weak var container: UIView!
    @IBOutlet private weak var contentsContainer: UIView!
    @IBOutlet private weak var leftTitleLabel: UILabel!
    @IBOutlet private weak var rightTitleLabel: UILabel!
    @IBOutlet private weak var leftImageView: UIImageView!
    @IBOutlet private weak var rightImageView: UIImageView!
    @IBOutlet private weak var firstLabel: UILabel!
    @IBOutlet private weak var secondLabel: UILabel!
    @IBOutlet private weak var thirdLabel: UILabel!
    @IBOutlet private weak var fourthLabel: UILabel!
    @IBOutlet private weak var leftTitleContainer: UIView!
    @IBOutlet private weak var rightTitleContainer: UIView!
    @IBOutlet private weak var firstHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var secondHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var thirdHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var fourthHeightConstraint: NSLayoutConstraint!

    weak var delegate: AIScanResultItemCellDelegate?
    private var symptom: AIScanDisplaySymptomViewModel?
    private var calculatedHeight: CGFloat = 477
    private var leftRequestURL: URL?
    private var rightRequestURL: URL?

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { configureAfterNibLoad() }
    }

    private func configureAfterNibLoad() {
        contentsContainer.layer.cornerRadius = 20
        contentsContainer.layer.masksToBounds = false
        contentsContainer.layer.shadowOpacity = 0.10
        contentsContainer.layer.shadowOffset = .zero
        contentsContainer.layer.shadowRadius = 12
        leftTitleContainer.layer.cornerRadius = 13
        rightTitleContainer.layer.cornerRadius = 13
        leftTitleContainer.layer.masksToBounds = true
        rightTitleContainer.layer.masksToBounds = true
        leftImageView.layer.cornerRadius = 34
        rightImageView.layer.cornerRadius = 34
        leftTitleLabel.text = AIScanReferenceStrings.localized(.originalPhoto)
        rightTitleLabel.text = AIScanReferenceStrings.localized(.analysisPhoto)
        applyTheme()

        // Preserve the original self-sizing behavior. Required horizontal IB
        // constraints otherwise conflict with UICollectionView's temporary
        // encapsulated width while the cell is first measured.
        for constraint in contentView.constraints where
            constraint.firstAttribute != .width &&
            constraint.firstAttribute != .height &&
            constraint.priority == .required {
            constraint.priority = UILayoutPriority(999)
        }
    }

    func configure(symptom: AIScanDisplaySymptomViewModel) {
        configure(symptom: symptom, loadsImages: true)
    }

    func configureForSizing(symptom: AIScanDisplaySymptomViewModel) {
        configure(symptom: symptom, loadsImages: false)
    }

    private func configure(
        symptom: AIScanDisplaySymptomViewModel,
        loadsImages: Bool
    ) {
        self.symptom = symptom
        if loadsImages {
            bindImage(symptom.cropImageURL, to: leftImageView, request: \Self.leftRequestURL)
            bindImage(symptom.heatmapURL ?? symptom.cropImageURL, to: rightImageView, request: \Self.rightRequestURL)
        }

        let labels = [firstLabel, secondLabel, thirdLabel, fourthLabel]
        let constraints = [firstHeightConstraint, secondHeightConstraint, thirdHeightConstraint, fourthHeightConstraint]
        let originalOrdinalIcons = [
            "vuesaxBoldMessageNotif",
            "iconPageClipboardTick",
            "iconPageDanger",
            "iconPageHospital"
        ]
        let rows = Array(symptom.detailRows.prefix(4))
        for index in labels.indices {
            guard index < rows.count else {
                labels[index]?.attributedText = nil
                labels[index]?.isHidden = true
                constraints[index]?.constant = 0
                continue
            }
            let row = rows[index]
            let label = labels[index]!
            label.isHidden = false
            label.font = .systemFont(ofSize: 14)
            label.attributedText = attributedText(
                for: row,
                fallbackIconName: originalOrdinalIcons[index]
            )
            constraints[index]?.constant = 0
        }
        updateCalculatedHeight(for: max(bounds.width, 1))
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
            if let symptom { configure(symptom: symptom) }
        }
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let width = layoutAttributes.aiscanResultFittedWidth
        updateCalculatedHeight(for: width)
        layoutAttributes.size = CGSize(width: width, height: calculatedHeight)
        return layoutAttributes
    }

    private func updateCalculatedHeight(for width: CGFloat) {
        let labels = [firstLabel, secondLabel, thirdLabel, fourthLabel]
        let constraints = [firstHeightConstraint, secondHeightConstraint, thirdHeightConstraint, fourthHeightConstraint]
        var textHeight: CGFloat = 0
        var visibleCount = 0
        for index in labels.indices {
            guard let label = labels[index], !label.isHidden else {
                constraints[index]?.constant = 0
                continue
            }
            let measured = ceil(label.sizeThatFits(
                CGSize(width: max(0, width - 90), height: .greatestFiniteMagnitude)
            ).height)
            constraints[index]?.constant = measured
            textHeight += measured
            visibleCount += 1
        }
        calculatedHeight = 297 + textHeight + CGFloat(max(0, visibleCount - 1)) * 12
    }

    @IBAction private func didTapLeftButton(_ sender: Any) {
        guard let url = symptom?.cropImageURL else { return }
        delegate?.resultItemCell(self, didSelectImageURL: url)
    }

    @IBAction private func didTapRightButton(_ sender: Any) {
        guard let url = symptom?.heatmapURL ?? symptom?.cropImageURL else { return }
        delegate?.resultItemCell(self, didSelectImageURL: url)
    }

    private func bindImage(
        _ url: URL?,
        to imageView: UIImageView,
        request: ReferenceWritableKeyPath<AIScanResultItemCell, URL?>
    ) {
        self[keyPath: request] = url
        imageView.image = nil
        guard let url else { return }
        AIScanReferenceImageLoader.load(from: url) { [weak self, weak imageView] image in
            guard let self, self[keyPath: request] == url, let imageView else { return }
            UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve) {
                imageView.image = image
            }
        }
    }

    private func attributedText(
        for row: AIScanDisplayDetailRowViewModel,
        fallbackIconName: String
    ) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 14)
        let parsed = lightweightAttributedText(from: row.text, baseFont: font)

        let result = NSMutableAttributedString()
        if let image = UIImage(
               named: row.iconName ?? fallbackIconName,
               in: AIScanReferenceStrings.resourceBundle,
               compatibleWith: traitCollection
           ) {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(
                x: 0,
                y: (font.capHeight - image.size.height) / 2,
                width: image.size.width,
                height: image.size.height
            )
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: "\t"))
        }
        result.append(parsed)

        let indent: CGFloat = 24
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = 0
        paragraph.headIndent = indent
        paragraph.tabStops = [
            NSTextTab(textAlignment: .left, location: indent, options: [:])
        ]
        paragraph.defaultTabInterval = indent
        paragraph.lineBreakMode = .byWordWrapping
        result.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }

    private func lightweightAttributedText(
        from html: String,
        baseFont: UIFont
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        var cursor = html.startIndex
        var boldDepth = 0

        while cursor < html.endIndex {
            guard let open = html[cursor...].firstIndex(of: "<"),
                  let close = html[open...].firstIndex(of: ">") else {
                appendText(
                    String(html[cursor...]),
                    bold: boldDepth > 0,
                    baseFont: baseFont,
                    to: result
                )
                break
            }
            appendText(
                String(html[cursor..<open]),
                bold: boldDepth > 0,
                baseFont: baseFont,
                to: result
            )
            let tag = html[html.index(after: open)..<close]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            switch tag {
            case "b", "strong":
                boldDepth += 1
            case "/b", "/strong":
                boldDepth = max(0, boldDepth - 1)
            case "br", "br/", "br /", "/p", "/li":
                if result.string.last != "\n" {
                    appendText("\n", bold: false, baseFont: baseFont, to: result)
                }
            case "li":
                if !result.string.isEmpty, result.string.last != "\n" {
                    appendText("\n", bold: false, baseFont: baseFont, to: result)
                }
                appendText("• ", bold: boldDepth > 0, baseFont: baseFont, to: result)
            default:
                break
            }
            cursor = html.index(after: close)
        }

        while result.string.last == "\n" {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return result
    }

    private func appendText(
        _ text: String,
        bold: Bool,
        baseFont: UIFont,
        to result: NSMutableAttributedString
    ) {
        guard !text.isEmpty else { return }
        let decoded = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        result.append(NSAttributedString(
            string: decoded,
            attributes: [
                .font: bold ? UIFont.boldSystemFont(ofSize: baseFont.pointSize) : baseFont,
                .foregroundColor: AIScanReferenceTheme.bodyText,
            ]
        ))
    }

    private func applyTheme() {
        backgroundColor = AIScanReferenceTheme.background
        contentView.backgroundColor = AIScanReferenceTheme.background
        container.backgroundColor = AIScanReferenceTheme.background
        contentsContainer.backgroundColor = AIScanReferenceTheme.surface
        contentsContainer.layer.shadowColor = AIScanReferenceTheme.resolvedCGColor(
            AIScanReferenceTheme.shadow,
            traits: traitCollection
        )
        leftImageView.backgroundColor = AIScanReferenceTheme.disabledSurface
        rightImageView.backgroundColor = AIScanReferenceTheme.disabledSurface
        leftTitleContainer.backgroundColor = AIScanReferenceTheme.originalCaptionBackground
        rightTitleContainer.backgroundColor = AIScanReferenceTheme.analysisCaptionBackground
        leftTitleLabel.backgroundColor = .clear
        rightTitleLabel.backgroundColor = .clear
        leftTitleLabel.textColor = AIScanReferenceTheme.originalCaptionText
        rightTitleLabel.textColor = AIScanReferenceTheme.analysisCaptionText
        [firstLabel, secondLabel, thirdLabel, fourthLabel].forEach {
            $0?.textColor = AIScanReferenceTheme.bodyText
            guard let attributedText = $0?.attributedText else { return }
            let mutable = NSMutableAttributedString(attributedString: attributedText)
            mutable.addAttribute(
                .foregroundColor,
                value: AIScanReferenceTheme.bodyText,
                range: NSRange(location: 0, length: mutable.length)
            )
            $0?.attributedText = mutable
        }
    }
}

@objc(AIScanResultNoticeCell)
@MainActor
final class AIScanResultNoticeCell: UICollectionViewCell {
    static let reuseIdentifier = "ResultNoticeCell"
    @IBOutlet private weak var noticeLabel: UILabel!

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { applyTheme() }
    }

    func configure(text: String) {
        noticeLabel.text = text
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
        }
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()
        let target = CGSize(
            width: layoutAttributes.aiscanResultFittedWidth,
            height: UIView.layoutFittingCompressedSize.height
        )
        let size = contentView.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        layoutAttributes.size = CGSize(width: target.width, height: ceil(size.height))
        return layoutAttributes
    }

    private func applyTheme() {
        backgroundColor = AIScanReferenceTheme.background
        contentView.backgroundColor = AIScanReferenceTheme.background
        noticeLabel.textColor = AIScanReferenceTheme.noticeText
    }
}

@objc(AIScanResultSpaceCell)
@MainActor
final class AIScanResultSpaceCell: UICollectionViewCell {
    static let reuseIdentifier = "SpaceCell"
    var height: CGFloat = 10

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes.size = CGSize(width: layoutAttributes.aiscanResultFittedWidth, height: height)
        return layoutAttributes
    }
}

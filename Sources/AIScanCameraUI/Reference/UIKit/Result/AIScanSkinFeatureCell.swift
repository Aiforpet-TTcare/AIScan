import UIKit

struct AIScanSkinFeatureItem {
    let name: String
    let value: Int
    let total: Int
}

@MainActor
final class AIScanSkinFeatureCell: UICollectionViewCell {
    static let reuseIdentifier = "SkinFeatureCell"

    private let spacer = UIView()
    private let titleLabel = UILabel()
    private let board = UIView()
    private let rows = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func configure(features: AIScanDisplaySkinFeaturesViewModel) {
        configure(items: [
            AIScanSkinFeatureItem(
                name: AIScanReferenceStrings.localized(.skinSensitivity),
                value: features.sensitivity,
                total: features.total
            ),
            AIScanSkinFeatureItem(
                name: AIScanReferenceStrings.localized(.skinDryness),
                value: features.dryness,
                total: features.total
            ),
            AIScanSkinFeatureItem(
                name: AIScanReferenceStrings.localized(.skinRoughness),
                value: features.roughness,
                total: features.total
            )
        ])
    }

    func configure(items: [AIScanSkinFeatureItem], title: String? = nil) {
        if let title {
            titleLabel.text = title
        }
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in items {
            let row = AIScanSkinFeatureRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 26).isActive = true
            row.configure(name: item.name, value: item.value, total: item.total)
            rows.addArrangedSubview(row)
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyTheme()
        }
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()
        let targetWidth = layoutAttributes.aiscanResultFittedWidth
        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        layoutAttributes.size = CGSize(width: targetWidth, height: ceil(size.height))
        return layoutAttributes
    }

    private func setupUI() {
        spacer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spacer)

        titleLabel.text = AIScanReferenceStrings.localized(.skinDetails)
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        board.backgroundColor = AIScanSkinFeaturePalette.board
        board.layer.cornerRadius = 20
        board.layer.masksToBounds = true
        board.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(board)

        rows.axis = .vertical
        rows.spacing = 28
        rows.distribution = .fillEqually
        rows.translatesAutoresizingMaskIntoConstraints = false
        board.addSubview(rows)

        NSLayoutConstraint.activate([
            spacer.topAnchor.constraint(equalTo: contentView.topAnchor),
            spacer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            spacer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            spacer.heightAnchor.constraint(equalToConstant: 6),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            board.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 74),
            board.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            board.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            board.heightAnchor.constraint(equalToConstant: 184),
            contentView.bottomAnchor.constraint(equalTo: board.bottomAnchor, constant: 40),
            rows.topAnchor.constraint(equalTo: board.topAnchor, constant: 28),
            rows.leadingAnchor.constraint(equalTo: board.leadingAnchor, constant: 20),
            rows.trailingAnchor.constraint(equalTo: board.trailingAnchor, constant: -20)
        ])
        applyTheme()
    }

    private func applyTheme() {
        backgroundColor = AIScanReferenceTheme.background
        contentView.backgroundColor = AIScanReferenceTheme.background
        spacer.backgroundColor = AIScanReferenceTheme.skinSpacer
        titleLabel.textColor = AIScanReferenceTheme.textPrimary
    }
}

@MainActor
private final class AIScanSkinFeatureRowView: UIView {
    private let nameLabel = UILabel()
    private let line = UIView()
    private let dots = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func configure(name: String, value: Int, total: Int) {
        nameLabel.text = name
        dots.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let dotCount = max(1, total + 1)
        let selected = min(max(1, value + 1), dotCount)

        for index in 1...dotCount {
            if index == selected {
                let dot = UILabel()
                dot.backgroundColor = AIScanSkinFeaturePalette.level(selected)
                dot.textColor = .white
                dot.text = "\(value)"
                dot.font = .boldSystemFont(ofSize: 14)
                dot.textAlignment = .center
                dot.layer.cornerRadius = 13
                dot.layer.masksToBounds = true
                dot.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 26),
                    dot.heightAnchor.constraint(equalToConstant: 26)
                ])
                dots.addArrangedSubview(dot)
            } else {
                let dot = UIView()
                dot.backgroundColor = AIScanSkinFeaturePalette.board
                dot.layer.cornerRadius = 7
                dot.layer.masksToBounds = true
                dot.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 14),
                    dot.heightAnchor.constraint(equalToConstant: 14)
                ])
                let inner = UIView()
                inner.backgroundColor = AIScanSkinFeaturePalette.dotIdle
                inner.layer.cornerRadius = 5
                inner.layer.masksToBounds = true
                inner.translatesAutoresizingMaskIntoConstraints = false
                dot.addSubview(inner)
                NSLayoutConstraint.activate([
                    inner.widthAnchor.constraint(equalToConstant: 10),
                    inner.heightAnchor.constraint(equalToConstant: 10),
                    inner.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                    inner.centerYAnchor.constraint(equalTo: dot.centerYAnchor)
                ])
                dots.addArrangedSubview(dot)
            }
        }
        accessibilityLabel = "\(name), \(selected) of \(dotCount)"
        isAccessibilityElement = true
    }

    private func setupUI() {
        nameLabel.font = .systemFont(ofSize: 14)
        nameLabel.textColor = .white
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.75
        line.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        line.layer.cornerRadius = 1
        dots.axis = .horizontal
        dots.alignment = .center
        dots.distribution = .equalSpacing
        [nameLabel, line, dots].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 120),
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 140),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.centerYAnchor.constraint(equalTo: centerYAnchor),
            line.heightAnchor.constraint(equalToConstant: 2),
            dots.leadingAnchor.constraint(equalTo: line.leadingAnchor),
            dots.trailingAnchor.constraint(equalTo: line.trailingAnchor),
            dots.centerYAnchor.constraint(equalTo: line.centerYAnchor),
            dots.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
}

private enum AIScanSkinFeaturePalette {
    static let board = color(0x2B3D6B)
    static let dotIdle = color(0x5C6FA0)
    static let levelOne = color(0x368DF5)
    static let levelTwo = color(0xFF970D)
    static let levelThree = color(0xFA535F)
    static let levelZero = color(0x43BA12)

    static func level(_ value: Int) -> UIColor {
        switch value {
        case 2: levelOne
        case 3: levelTwo
        case 4: levelThree
        default: levelZero
        }
    }

    private static func color(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

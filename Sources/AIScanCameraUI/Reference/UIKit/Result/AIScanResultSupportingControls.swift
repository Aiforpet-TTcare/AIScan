import UIKit

/// Original result footer. It is only installed when a real export action is
/// supplied, so the source UI never presents a non-functional CTA.
@MainActor
final class AIScanPDFExportFooterView: UICollectionReusableView {
    static let reuseIdentifier = "AIScanPDFExportFooterView"

    var onTap: (() -> Void)?
    private let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = AIScanReferenceTheme.exportAction
        button.layer.cornerRadius = 16
        button.layer.cornerCurve = .continuous
        button.tintColor = AIScanReferenceTheme.onBrand
        button.setTitleColor(AIScanReferenceTheme.onBrand, for: .normal)
        button.setTitle(AIScanReferenceStrings.localized(.exportReport), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(
            UIImage(systemName: "square.and.arrow.up", withConfiguration: symbolConfiguration),
            for: .normal
        )
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
        button.accessibilityLabel = AIScanReferenceStrings.localized(.exportReport)
        button.accessibilityIdentifier = "aiscan.result.export-pdf"
        if #available(iOS 14.0, *) {
            button.addAction(
                UIAction { [weak self] _ in self?.onTap?() },
                for: .touchUpInside
            )
        } else {
            button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        }
        addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            button.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        button.backgroundColor = AIScanReferenceTheme.exportAction
        button.tintColor = AIScanReferenceTheme.onBrand
        button.setTitleColor(AIScanReferenceTheme.onBrand, for: .normal)
    }

    @objc private func handleTap() {
        onTap?()
    }
}

/// Original five-line shimmer surface, retained as a reusable loading view for
/// result/PDF content rather than the retired web-view implementation.
@MainActor
final class AIScanSkeletonView: UIView {
    var lineHeight: CGFloat = 40
    var lineSpacing: CGFloat = 25
    var cornerRadius: CGFloat = 8

    private var gradientLayers: [CAGradientLayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildLines()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        setNeedsLayout()
    }

    func startAnimating() {
        isHidden = false
        alpha = 1
        gradientLayers.forEach(addShimmerAnimation(to:))
    }

    func stopAnimating() {
        gradientLayers.forEach { $0.removeAnimation(forKey: "shimmer") }
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { [weak self] _ in
            self?.isHidden = true
        }
    }

    private func rebuildLines() {
        subviews.forEach { $0.removeFromSuperview() }
        gradientLayers.forEach { $0.removeFromSuperlayer() }
        gradientLayers.removeAll(keepingCapacity: true)

        let numberOfLines = Int(bounds.height / (lineHeight + lineSpacing))
        guard numberOfLines > 0 else { return }
        for index in 0..<numberOfLines {
            let line = UIView(
                frame: CGRect(
                    x: 0,
                    y: CGFloat(index) * (lineHeight + lineSpacing),
                    width: bounds.width,
                    height: lineHeight
                )
            )
            line.layer.cornerRadius = cornerRadius
            line.backgroundColor = AIScanReferenceTheme.skeletonBase
            addSubview(line)

            let gradient = CAGradientLayer()
            gradient.colors = [
                AIScanReferenceTheme.resolvedCGColor(
                    AIScanReferenceTheme.skeletonHighlight.withAlphaComponent(0.1),
                    traits: traitCollection
                ),
                AIScanReferenceTheme.resolvedCGColor(
                    AIScanReferenceTheme.skeletonHighlight.withAlphaComponent(0.8),
                    traits: traitCollection
                ),
                AIScanReferenceTheme.resolvedCGColor(
                    AIScanReferenceTheme.skeletonHighlight.withAlphaComponent(0.1),
                    traits: traitCollection
                ),
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.frame = line.bounds
            gradient.locations = [0, 0.5, 1]
            line.layer.addSublayer(gradient)
            gradientLayers.append(gradient)
            addShimmerAnimation(to: gradient)
        }
    }

    private func addShimmerAnimation(to gradient: CAGradientLayer) {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1, -0.5, 0]
        animation.toValue = [1, 1.5, 2]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        gradient.add(animation, forKey: "shimmer")
    }
}

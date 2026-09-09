import UIKit

/// Original retry-card page indicator used when more than one capture
/// rejection reason must be shown.
@MainActor
final class TTIndicatorView: UIView {
    private var circles: [UIView] = []
    private let numberOfCircles: Int
    private let circleSpacing: CGFloat

    init(numberOfCircles: Int, circleSpacing: CGFloat = 8) {
        self.numberOfCircles = numberOfCircles
        self.circleSpacing = circleSpacing
        let width = CGFloat(numberOfCircles * 8)
            + CGFloat(max(numberOfCircles - 1, 0)) * circleSpacing
            + 15
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: 8))
        accessibilityIdentifier = "aiscan.camera.retake.page-indicator"
        setupView()
        updateIndicator(forPage: 0, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func setupView() {
        for index in 0..<numberOfCircles {
            let circle = UIView()
            circle.layer.cornerRadius = 4
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.backgroundColor = AIScanLegacyText.indicatorInactive
            circle.accessibilityIdentifier = "aiscan.camera.retake.page.\(index)"
            addSubview(circle)
            circles.append(circle)

            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: 8),
                circle.heightAnchor.constraint(equalToConstant: 8),
            ])
            if index == 0 {
                circle.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            } else {
                circle.leadingAnchor.constraint(
                    equalTo: circles[index - 1].trailingAnchor,
                    constant: circleSpacing
                ).isActive = true
            }
        }
        circles.last?.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor).isActive = true
    }

    func updateIndicator(forPage page: Int, animated: Bool = true) {
        let changes = {
            for (index, circle) in self.circles.enumerated() {
                circle.backgroundColor = index == page
                    ? AIScanLegacyText.indicatorActive
                    : AIScanLegacyText.indicatorInactive
                NSLayoutConstraint.deactivate(circle.constraints)
                NSLayoutConstraint.activate([
                    circle.widthAnchor.constraint(equalToConstant: index == page ? 23 : 8),
                    circle.heightAnchor.constraint(equalToConstant: 8),
                ])
                circle.layer.cornerRadius = 4
            }
            self.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: changes)
        } else {
            changes()
        }
    }
}

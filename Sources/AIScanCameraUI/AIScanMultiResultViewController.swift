import UIKit
import AIScanCore

/// Optional built-in summary for a completed multi-photo scan.
@MainActor
public final class AIScanMultiResultViewController: UIViewController {
    public var onClose: (() -> Void)?
    public var onSelect: ((AISCDisplayResult) -> Void)?
    private let outcomes: [AIScanMultiPhotoOutcome]

    public init(outcomes: [AIScanMultiPhotoOutcome]) {
        self.outcomes = outcomes
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIScanReferenceTheme.background
        view.accessibilityIdentifier = "aiscan.multi.results"
        let title = UILabel()
        title.text = AIScanCameraStrings.localizedMessageKey("multi.result_title")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        title.textColor = AIScanReferenceTheme.textPrimary
        title.numberOfLines = 0
        let content = UIStackView(arrangedSubviews: [title])
        content.axis = .vertical; content.spacing = 16
        for (index, outcome) in outcomes.enumerated() {
            let button = UIButton(type: .system)
            let key = outcome.error != nil ? "multi.failed" : outcome.result?.requiresRetake == true ? "multi.retake" : "multi.complete"
            let caption = String(format: AIScanCameraStrings.localizedMessageKey("multi.photo"), outcome.photoIndex)
            let text = caption + " · " + AIScanCameraStrings.localizedMessageKey(key)
            button.setTitle(text, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            button.titleLabel?.numberOfLines = 0
            button.contentHorizontalAlignment = .leading
            button.contentEdgeInsets = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
            button.layer.cornerRadius = 12
            button.backgroundColor = AIScanReferenceTheme.surfaceSecondary
            button.setTitleColor(AIScanReferenceTheme.textPrimary, for: .normal)
            button.accessibilityIdentifier = "aiscan.multi.result.\(outcome.photoIndex)"
            button.isEnabled = outcome.result != nil && outcome.result?.requiresRetake == false
            button.tag = index
            button.addTarget(self, action: #selector(selected(_:)), for: .touchUpInside)
            content.addArrangedSubview(button)
            if let message = outcome.errorMessage {
                let label = UILabel()
                label.text = message; label.numberOfLines = 0
                label.font = .systemFont(ofSize: 15)
                label.textColor = AIScanReferenceTheme.textSecondary
                content.addArrangedSubview(label)
            }
        }
        let scroll = UIScrollView(); scroll.addSubview(content)
        let close = UIButton(type: .system)
        close.setTitle(AIScanCameraStrings.localized(.close), for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        close.backgroundColor = AIScanReferenceTheme.brandPrimary
        close.setTitleColor(AIScanReferenceTheme.onBrand, for: .normal)
        close.layer.cornerRadius = 14
        close.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        [scroll, close].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(equalTo: close.topAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            close.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            close.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])
    }
    @objc private func selected(_ button: UIButton) {
        guard outcomes.indices.contains(button.tag), let result = outcomes[button.tag].result else { return }
        onSelect?(result)
    }
    @objc private func closeTapped() { onClose?() }
}

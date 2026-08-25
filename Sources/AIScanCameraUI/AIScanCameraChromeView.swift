import UIKit

@MainActor
final class AIScanCameraChromeView: UIView {
    var onCapture: (() -> Void)?
    var onClose: (() -> Void)?
    var onRetry: (() -> Void)?

    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let percentLabel = UILabel()
    private let captureButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let guideView = AIScanCameraGuideView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        apply(state: .preparing)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func apply(state: AIScanCameraPresentationState) {
        retryButton.isHidden = true
        captureButton.isEnabled = false

        switch state {
        case .preparing:
            statusLabel.text = AIScanCameraStrings.localized(.preparing)
        case .scanning:
            statusLabel.text = AIScanCameraStrings.localized(.scanning)
        case .ready:
            statusLabel.text = AIScanCameraStrings.localized(.ready)
            captureButton.isEnabled = true
        case .analyzing:
            statusLabel.text = AIScanCameraStrings.localized(.analyzing)
        case .complete:
            statusLabel.text = AIScanCameraStrings.localized(.complete)
        case let .error(message):
            statusLabel.text = message
            retryButton.isHidden = false
        }
    }

    func setProgress(_ progress: Float, animated: Bool) {
        let normalized = min(max(progress, 0), 1)
        progressView.setProgress(normalized, animated: animated)
        let percentage = Int((normalized * 100).rounded())
        let update = { [weak self] in
            self?.percentLabel.text = "\(percentage)%"
            self?.percentLabel.accessibilityValue = "\(percentage)%"
        }
        guard animated else {
            update()
            return
        }
        UIView.transition(
            with: percentLabel,
            duration: 0.2,
            options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction],
            animations: update
        )
    }

    private func configureLayout() {
        backgroundColor = .clear

        guideView.translatesAutoresizingMaskIntoConstraints = false
        guideView.isAccessibilityElement = false
        guideView.accessibilityElementsHidden = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.accessibilityIdentifier = "aiscan.camera.status"

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.accessibilityIdentifier = "aiscan.camera.progress"

        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.text = "0%"
        percentLabel.textColor = .white
        percentLabel.textAlignment = .center
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        percentLabel.adjustsFontForContentSizeCategory = true
        percentLabel.accessibilityIdentifier = "aiscan.camera.progress.percent"
        percentLabel.accessibilityValue = "0%"

        var captureConfiguration = UIButton.Configuration.filled()
        captureConfiguration.image = UIImage(systemName: "camera.fill")
        captureConfiguration.baseBackgroundColor = .white
        captureConfiguration.baseForegroundColor = .black
        captureConfiguration.cornerStyle = .capsule
        captureButton.configuration = captureConfiguration
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.accessibilityLabel = AIScanCameraStrings.localized(.capture)
        captureButton.accessibilityIdentifier = "aiscan.camera.capture"
        captureButton.addAction(UIAction { [weak self] _ in
            self?.onCapture?()
        }, for: .touchUpInside)

        var closeConfiguration = UIButton.Configuration.plain()
        closeConfiguration.image = UIImage(systemName: "xmark")
        closeConfiguration.baseForegroundColor = .white
        closeButton.configuration = closeConfiguration
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.accessibilityLabel = AIScanCameraStrings.localized(.close)
        closeButton.accessibilityIdentifier = "aiscan.camera.close"
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)

        var retryConfiguration = UIButton.Configuration.bordered()
        retryConfiguration.title = AIScanCameraStrings.localized(.retry)
        retryConfiguration.baseForegroundColor = .white
        retryButton.configuration = retryConfiguration
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.accessibilityLabel = AIScanCameraStrings.localized(.retry)
        retryButton.accessibilityIdentifier = "aiscan.camera.retry"
        retryButton.addAction(UIAction { [weak self] _ in
            self?.onRetry?()
        }, for: .touchUpInside)

        [guideView, statusLabel, percentLabel, progressView, captureButton, closeButton, retryButton]
            .forEach(addSubview)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            guideView.centerXAnchor.constraint(equalTo: centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -70),
            guideView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, constant: -64),
            guideView.heightAnchor.constraint(equalTo: guideView.widthAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            statusLabel.bottomAnchor.constraint(equalTo: percentLabel.topAnchor, constant: -8),

            percentLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            percentLabel.bottomAnchor.constraint(equalTo: retryButton.topAnchor, constant: -8),

            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -16),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            progressView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 48),
            progressView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -48),
            progressView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -28),

            captureButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -28),
            captureButton.widthAnchor.constraint(equalToConstant: 72),
            captureButton.heightAnchor.constraint(equalToConstant: 72),
        ])
    }
}

private final class AIScanCameraGuideView: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let inset: CGFloat = 3
        let length = min(rect.width, rect.height) * 0.22
        let radius: CGFloat = 18
        let bounds = rect.insetBy(dx: inset, dy: inset)

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.82).cgColor)
        context.setLineWidth(5)
        context.setLineCap(.round)

        let path = UIBezierPath()
        addCorner(
            to: path,
            start: CGPoint(x: bounds.minX, y: bounds.minY + length),
            line: CGPoint(x: bounds.minX, y: bounds.minY + radius),
            center: CGPoint(x: bounds.minX + radius, y: bounds.minY + radius),
            startAngle: .pi,
            endAngle: .pi * 1.5,
            end: CGPoint(x: bounds.minX + length, y: bounds.minY)
        )
        addCorner(
            to: path,
            start: CGPoint(x: bounds.maxX - length, y: bounds.minY),
            line: CGPoint(x: bounds.maxX - radius, y: bounds.minY),
            center: CGPoint(x: bounds.maxX - radius, y: bounds.minY + radius),
            startAngle: -.pi / 2,
            endAngle: 0,
            end: CGPoint(x: bounds.maxX, y: bounds.minY + length)
        )
        addCorner(
            to: path,
            start: CGPoint(x: bounds.maxX, y: bounds.maxY - length),
            line: CGPoint(x: bounds.maxX, y: bounds.maxY - radius),
            center: CGPoint(x: bounds.maxX - radius, y: bounds.maxY - radius),
            startAngle: 0,
            endAngle: .pi / 2,
            end: CGPoint(x: bounds.maxX - length, y: bounds.maxY)
        )
        addCorner(
            to: path,
            start: CGPoint(x: bounds.minX + length, y: bounds.maxY),
            line: CGPoint(x: bounds.minX + radius, y: bounds.maxY),
            center: CGPoint(x: bounds.minX + radius, y: bounds.maxY - radius),
            startAngle: .pi / 2,
            endAngle: .pi,
            end: CGPoint(x: bounds.minX, y: bounds.maxY - length)
        )

        context.addPath(path.cgPath)
        context.strokePath()
    }

    private func addCorner(
        to path: UIBezierPath,
        start: CGPoint,
        line: CGPoint,
        center: CGPoint,
        startAngle: CGFloat,
        endAngle: CGFloat,
        end: CGPoint
    ) {
        path.move(to: start)
        path.addLine(to: line)
        path.addArc(
            withCenter: center,
            radius: 18,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        path.addLine(to: end)
    }
}

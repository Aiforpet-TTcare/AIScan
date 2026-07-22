import UIKit
import AIScanCore

@MainActor
final class AIScanCameraChromeView: UIView {
    var onCapture: (() -> Void)?
    var onClose: (() -> Void)?
    var onRetry: (() -> Void)?
    var onFlashChanged: ((Bool) -> Void)?
    var onAlbum: (() -> Void)?
    var onStart: (() -> Void)?

    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let captureButton = AIScanCaptureButton(type: .custom)
    private let closeButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let albumButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let guideView = AIScanCameraGuideView()
    private let startPrompt = AIScanFlashPromptView()
    private var isFlashEnabled = false
    private var hasStarted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        apply(state: .preparing)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(partType: AISCPartType, displaySubpart: String?) {
        guideView.configure(partType: partType, displaySubpart: displaySubpart)
    }

    func apply(state: AIScanCameraPresentationState) {
        retryButton.isHidden = true
        captureButton.isEnabled = false
        progressView.isHidden = false

        switch state {
        case .preparing:
            statusLabel.text = AIScanCameraStrings.localized(.preparing)
        case .scanning:
            statusLabel.text = AIScanCameraStrings.localized(.scanning)
        case .ready:
            statusLabel.text = AIScanCameraStrings.localized(.ready)
            captureButton.isEnabled = hasStarted
        case .analyzing:
            statusLabel.text = AIScanCameraStrings.localized(.analyzing)
        case .complete:
            statusLabel.text = AIScanCameraStrings.localized(.complete)
        case let .error(message):
            startPrompt.isHidden = true
            statusLabel.text = message
            retryButton.isHidden = false
            progressView.isHidden = true
        }
        captureButton.alpha = captureButton.isEnabled ? 1 : 0.62
    }

    func setProgress(_ progress: Float, animated: Bool) {
        progressView.setProgress(progress, animated: animated)
    }

    func resetStartPrompt() {
        hasStarted = false
        albumButton.isHidden = true
        startPrompt.isHidden = false
    }

    private func configureLayout() {
        backgroundColor = .clear

        guideView.translatesAutoresizingMaskIntoConstraints = false
        guideView.isAccessibilityElement = false
        guideView.accessibilityElementsHidden = true
        guideView.accessibilityIdentifier = "aiscan.camera.guide"

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.accessibilityIdentifier = "aiscan.camera.status"

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(red: 1, green: 0.42, blue: 0.34, alpha: 1)
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        progressView.accessibilityIdentifier = "aiscan.camera.progress"

        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.accessibilityLabel = AIScanCameraStrings.localized(.capture)
        captureButton.accessibilityIdentifier = "aiscan.camera.capture"
        captureButton.addAction(UIAction { [weak self] _ in
            self?.onCapture?()
        }, for: .touchUpInside)

        configureIconButton(
            closeButton,
            symbol: "xmark",
            label: AIScanCameraStrings.localized(.close),
            identifier: "aiscan.camera.close"
        )
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)

        configureIconButton(
            flashButton,
            symbol: "bolt.slash",
            label: AIScanCameraStrings.localized(.flash),
            identifier: "aiscan.camera.flash"
        )
        flashButton.addAction(UIAction { [weak self] _ in
            self?.toggleFlash()
        }, for: .touchUpInside)

        configureIconButton(
            albumButton,
            symbol: "photo.on.rectangle",
            label: AIScanCameraStrings.localized(.album),
            identifier: "aiscan.camera.album"
        )
        albumButton.isHidden = true
        albumButton.addAction(UIAction { [weak self] _ in
            self?.onAlbum?()
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

        startPrompt.translatesAutoresizingMaskIntoConstraints = false
        startPrompt.accessibilityIdentifier = "aiscan.camera.start-prompt"
        startPrompt.onFlashChanged = { [weak self] enabled in
            self?.setFlash(enabled)
        }
        startPrompt.onStart = { [weak self] in
            self?.beginUserScan()
        }

        [guideView, statusLabel, progressView, captureButton, closeButton,
         flashButton, albumButton, retryButton, startPrompt]
            .forEach(addSubview)

        NSLayoutConstraint.activate([
            flashButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            flashButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 18),
            flashButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            flashButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            guideView.centerXAnchor.constraint(equalTo: centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -88),
            guideView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, constant: -64),
            guideView.heightAnchor.constraint(equalTo: guideView.widthAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            statusLabel.topAnchor.constraint(equalTo: guideView.bottomAnchor, constant: 20),

            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -16),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            progressView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 64),
            progressView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -64),
            progressView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -28),

            captureButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -28),
            captureButton.widthAnchor.constraint(equalToConstant: 82),
            captureButton.heightAnchor.constraint(equalToConstant: 82),

            albumButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            albumButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 30),
            albumButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
            albumButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            startPrompt.leadingAnchor.constraint(equalTo: leadingAnchor),
            startPrompt.trailingAnchor.constraint(equalTo: trailingAnchor),
            startPrompt.topAnchor.constraint(equalTo: topAnchor),
            startPrompt.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func configureIconButton(
        _ button: UIButton,
        symbol: String,
        label: String,
        identifier: String
    ) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 25,
            weight: .light
        )
        configuration.baseForegroundColor = .white
        button.configuration = configuration
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = label
        button.accessibilityIdentifier = identifier
    }

    private func beginUserScan() {
        hasStarted = true
        startPrompt.isHidden = true
        albumButton.isHidden = false
        captureButton.isEnabled = true
        captureButton.alpha = 1
        onStart?()
    }

    private func toggleFlash() {
        setFlash(!isFlashEnabled)
    }

    private func setFlash(_ enabled: Bool) {
        isFlashEnabled = enabled
        flashButton.configuration?.image = UIImage(
            systemName: enabled ? "bolt.fill" : "bolt.slash"
        )
        startPrompt.setFlashEnabled(enabled)
        onFlashChanged?(enabled)
    }
}

private final class AIScanFlashPromptView: UIView {
    var onFlashChanged: ((Bool) -> Void)?
    var onStart: (() -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let actionContainer = UIView()
    private let actionLabel = UILabel()
    private let bodyLabel = UILabel()
    private let flashSwitch = UISwitch()
    private let startButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func setFlashEnabled(_ enabled: Bool) {
        guard flashSwitch.isOn != enabled else { return }
        flashSwitch.setOn(enabled, animated: true)
    }

    private func configureLayout() {
        backgroundColor = UIColor.black.withAlphaComponent(0.56)

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .white
        card.layer.cornerRadius = 34
        card.layer.cornerCurve = .continuous

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = AIScanCameraStrings.localized(.flashRecommendationTitle)
        titleLabel.textColor = UIColor(white: 0.10, alpha: 1)
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        actionContainer.translatesAutoresizingMaskIntoConstraints = false
        actionContainer.layer.cornerRadius = 18
        actionContainer.layer.cornerCurve = .continuous
        actionContainer.layer.borderWidth = 1
        actionContainer.layer.borderColor = UIColor(white: 0.90, alpha: 1).cgColor

        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.attributedText = flashActionText()
        actionLabel.numberOfLines = 0
        actionLabel.lineBreakMode = .byWordWrapping

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.attributedText = flashBodyText()
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping

        flashSwitch.translatesAutoresizingMaskIntoConstraints = false
        flashSwitch.accessibilityLabel = AIScanCameraStrings.localized(.flash)
        flashSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onFlashChanged?(self.flashSwitch.isOn)
        }, for: .valueChanged)

        var startConfiguration = UIButton.Configuration.filled()
        startConfiguration.title = AIScanCameraStrings.localized(.start)
        startConfiguration.baseBackgroundColor = UIColor(red: 0.20, green: 0.20, blue: 0.30, alpha: 1)
        startConfiguration.baseForegroundColor = .white
        startConfiguration.background.cornerRadius = 10
        startConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 15, weight: .bold)
            return attributes
        }
        startButton.configuration = startConfiguration
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.accessibilityLabel = AIScanCameraStrings.localized(.start)
        startButton.accessibilityIdentifier = "aiscan.camera.start"
        startButton.addAction(UIAction { [weak self] _ in
            self?.onStart?()
        }, for: .touchUpInside)

        addSubview(card)
        [titleLabel, actionContainer, bodyLabel, startButton]
            .forEach(card.addSubview)
        [actionLabel, flashSwitch].forEach(actionContainer.addSubview)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.widthAnchor.constraint(equalToConstant: 315),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            actionContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            actionContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            actionContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            actionContainer.heightAnchor.constraint(equalToConstant: 80),

            actionLabel.centerYAnchor.constraint(equalTo: actionContainer.centerYAnchor),
            actionLabel.leadingAnchor.constraint(equalTo: actionContainer.leadingAnchor, constant: 20),
            actionLabel.trailingAnchor.constraint(equalTo: flashSwitch.leadingAnchor, constant: -16),

            flashSwitch.centerYAnchor.constraint(equalTo: actionContainer.centerYAnchor),
            flashSwitch.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor, constant: -20),

            bodyLabel.topAnchor.constraint(equalTo: actionContainer.bottomAnchor, constant: 10),
            bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22),

            startButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 20),
            startButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            startButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
    }

    private func flashActionText() -> NSAttributedString {
        let value = AIScanCameraStrings.localized(.flashRecommendationAction)
        let accent = AIScanCameraStrings.localized(.flashRecommendationActionAccent)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.lineBreakMode = .byWordWrapping
        let result = NSMutableAttributedString(
            string: value,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor(white: 0.44, alpha: 1),
                .paragraphStyle: paragraph,
            ]
        )
        let range = (value as NSString).range(of: accent)
        if range.location != NSNotFound {
            result.addAttribute(
                .foregroundColor,
                value: UIColor(red: 54 / 255, green: 141 / 255, blue: 245 / 255, alpha: 1),
                range: range
            )
        }
        return result
    }

    private func flashBodyText() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: AIScanCameraStrings.localized(.flashRecommendationBody),
            attributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor(white: 0.44, alpha: 1),
                .paragraphStyle: paragraph,
            ]
        )
    }
}

private final class AIScanCaptureButton: UIButton {
    private let gradientLayer = CAGradientLayer()
    private let ringMask = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        layer.addSublayer(gradientLayer)
        gradientLayer.colors = [
            UIColor(red: 1, green: 0.36, blue: 0.47, alpha: 1).cgColor,
            UIColor(red: 1, green: 0.74, blue: 0.16, alpha: 1).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.mask = ringMask
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        let path = UIBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4))
        ringMask.path = path.cgPath
        ringMask.fillColor = UIColor.clear.cgColor
        ringMask.strokeColor = UIColor.black.cgColor
        ringMask.lineWidth = 7
    }
}

private final class AIScanCameraGuideView: UIView {
    private var partType: AISCPartType = .eye
    private var displaySubpart: String?

    func configure(partType: AISCPartType, displaySubpart: String?) {
        self.partType = partType
        self.displaySubpart = displaySubpart
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        drawCorners(in: rect)

        switch partType {
        case .eye:
            drawEye(in: rect)
        case .teeth:
            drawMouth(in: rect)
        case .joint:
            drawJoint(in: rect)
        case .skin, .unknown:
            drawSkinGuide(in: rect)
        @unknown default:
            drawSkinGuide(in: rect)
        }
    }

    private func drawCorners(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let inset: CGFloat = 3
        let length = min(rect.width, rect.height) * 0.20
        let radius: CGFloat = 18
        let bounds = rect.insetBy(dx: inset, dy: inset)

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.84).cgColor)
        context.setLineWidth(5)
        context.setLineCap(.round)

        let path = UIBezierPath()
        addCorner(to: path, start: CGPoint(x: bounds.minX, y: bounds.minY + length), line: CGPoint(x: bounds.minX, y: bounds.minY + radius), center: CGPoint(x: bounds.minX + radius, y: bounds.minY + radius), startAngle: .pi, endAngle: .pi * 1.5, end: CGPoint(x: bounds.minX + length, y: bounds.minY))
        addCorner(to: path, start: CGPoint(x: bounds.maxX - length, y: bounds.minY), line: CGPoint(x: bounds.maxX - radius, y: bounds.minY), center: CGPoint(x: bounds.maxX - radius, y: bounds.minY + radius), startAngle: -.pi / 2, endAngle: 0, end: CGPoint(x: bounds.maxX, y: bounds.minY + length))
        addCorner(to: path, start: CGPoint(x: bounds.maxX, y: bounds.maxY - length), line: CGPoint(x: bounds.maxX, y: bounds.maxY - radius), center: CGPoint(x: bounds.maxX - radius, y: bounds.maxY - radius), startAngle: 0, endAngle: .pi / 2, end: CGPoint(x: bounds.maxX - length, y: bounds.maxY))
        addCorner(to: path, start: CGPoint(x: bounds.minX + length, y: bounds.maxY), line: CGPoint(x: bounds.minX + radius, y: bounds.maxY), center: CGPoint(x: bounds.minX + radius, y: bounds.maxY - radius), startAngle: .pi / 2, endAngle: .pi, end: CGPoint(x: bounds.minX, y: bounds.maxY - length))
        context.addPath(path.cgPath)
        context.strokePath()
    }

    private func drawEye(in rect: CGRect) {
        let width = rect.width * 0.46
        let height = width * 0.52
        let eyeRect = CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: eyeRect.minX, y: eyeRect.midY))
        path.addQuadCurve(to: CGPoint(x: eyeRect.maxX, y: eyeRect.midY), controlPoint: CGPoint(x: eyeRect.midX, y: eyeRect.minY))
        path.addQuadCurve(to: CGPoint(x: eyeRect.minX, y: eyeRect.midY), controlPoint: CGPoint(x: eyeRect.midX, y: eyeRect.maxY))
        let iris = UIBezierPath(ovalIn: eyeRect.insetBy(dx: width * 0.28, dy: height * 0.08))
        strokeGuide(path)
        strokeGuide(iris)
    }

    private func drawMouth(in rect: CGRect) {
        let guideRect = rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.36)
        strokeGuide(UIBezierPath(roundedRect: guideRect, cornerRadius: guideRect.height / 2))
        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: guideRect.minX + 12, y: guideRect.midY))
        divider.addLine(to: CGPoint(x: guideRect.maxX - 12, y: guideRect.midY))
        strokeGuide(divider)
    }

    private func drawJoint(in rect: CGRect) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX - 44, y: rect.midY - 60))
        path.addCurve(to: CGPoint(x: rect.midX + 44, y: rect.midY + 60), controlPoint1: CGPoint(x: rect.midX + 36, y: rect.midY - 38), controlPoint2: CGPoint(x: rect.midX - 36, y: rect.midY + 38))
        strokeGuide(path)
    }

    private func drawSkinGuide(in rect: CGRect) {
        let guideRect = rect.insetBy(dx: rect.width * 0.27, dy: rect.height * 0.27)
        strokeGuide(UIBezierPath(roundedRect: guideRect, cornerRadius: 30))
    }

    private func strokeGuide(_ path: UIBezierPath) {
        UIColor.white.withAlphaComponent(0.72).setStroke()
        path.lineWidth = 4
        path.lineCapStyle = .round
        path.setLineDash([7, 7], count: 2, phase: 0)
        path.stroke()
    }

    private func addCorner(to path: UIBezierPath, start: CGPoint, line: CGPoint, center: CGPoint, startAngle: CGFloat, endAngle: CGFloat, end: CGPoint) {
        path.move(to: start)
        path.addLine(to: line)
        path.addArc(withCenter: center, radius: 18, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.addLine(to: end)
    }
}

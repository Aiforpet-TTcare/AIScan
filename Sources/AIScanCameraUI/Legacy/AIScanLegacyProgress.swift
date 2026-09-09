import UIKit

@MainActor
@objc(CountingLabel)
final class CountingLabel: UILabel {
    private var displayLink: CADisplayLink?
    private var startValue: Double = 0
    private var endValue: Double = 0
    private var displayedValue: Double = 0
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 0.4

    func update(to newValue: Int, duration: TimeInterval = 0.4) {
        let now = CACurrentMediaTime()
        if displayLink == nil {
            displayedValue = Double(text ?? "") ?? 0
        } else {
            displayedValue = interpolatedValue(at: now)
            text = "\(Int(displayedValue.rounded()))"
        }

        let target = Double(newValue)
        guard target != endValue || displayLink == nil else { return }
        if target < displayedValue {
            stopAnimation(at: target)
            return
        }

        startValue = displayedValue
        endValue = target
        let distance = abs(endValue - startValue)
        self.duration = min(duration, max(0.12, duration * distance / 20))
        startTime = now
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(updateValue))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func updateValue() {
        let now = CACurrentMediaTime()
        displayedValue = interpolatedValue(at: now)
        text = "\(Int(displayedValue.rounded()))"
        if now - startTime >= duration {
            stopAnimation(at: endValue)
        }
    }

    private func interpolatedValue(at now: CFTimeInterval) -> Double {
        guard duration > 0 else { return endValue }
        let linear = min(max((now - startTime) / duration, 0), 1)
        let eased = 1 - pow(1 - linear, 3)
        return startValue + ((endValue - startValue) * eased)
    }

    private func stopAnimation(at value: Double) {
        displayedValue = value
        startValue = value
        endValue = value
        text = "\(Int(value.rounded()))"
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {
        MainActor.assumeIsolated {
            displayLink?.invalidate()
        }
    }
}

@MainActor
final class DotAnimationView: UIView {
    private let dotCount = 20
    private let dotSize: CGFloat = 5
    private var initialized = false

    private var ovalRect: CGRect {
        let width = bounds.width * 0.8
        let height = bounds.height * 0.5
        return CGRect(
            x: (bounds.width - width) / 2,
            y: (bounds.height - height) / 2,
            width: width,
            height: height
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !initialized, !bounds.isEmpty else { return }
        initialized = true
        for _ in 0..<dotCount {
            let position = randomPointInOval(ovalRect)
            let dot = CAShapeLayer()
            dot.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: dotSize, height: dotSize)).cgPath
            dot.fillColor = UIColor.white.cgColor
            dot.frame = CGRect(x: position.x, y: position.y, width: dotSize, height: dotSize)
            dot.opacity = 0
            layer.addSublayer(dot)
        }
        startAnimations()
    }

    private func randomPointInOval(_ oval: CGRect) -> CGPoint {
        let center = CGPoint(x: oval.midX, y: oval.midY)
        let horizontalRadius = oval.width / 2
        let verticalRadius = oval.height / 2
        while true {
            let point = CGPoint(
                x: CGFloat.random(in: oval.minX...oval.maxX),
                y: CGFloat.random(in: oval.minY...oval.maxY)
            )
            let normalizedX = (point.x - center.x) / horizontalRadius
            let normalizedY = (point.y - center.y) / verticalRadius
            if normalizedX * normalizedX + normalizedY * normalizedY <= 1 {
                return point
            }
        }
    }

    func startAnimations() {
        layer.sublayers?.forEach { layer in
            guard layer.animation(forKey: "startEndFade") == nil else { return }
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = Double.random(in: 0.5...1)

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = Double.random(in: 0.5...1)
            fadeOut.beginTime = fadeIn.duration + Double.random(in: 1...2)

            let group = CAAnimationGroup()
            group.animations = [fadeIn, fadeOut]
            group.duration = fadeOut.beginTime + fadeOut.duration
            group.repeatCount = .infinity
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            layer.add(group, forKey: "startEndFade")
        }
    }

    func stopAnimations() {
        layer.sublayers?.forEach { $0.removeAnimation(forKey: "startEndFade") }
    }
}

/// Core-backed adapter for the unchanged original `TTEtc` progress scene.
@MainActor
@objc(TTProgressViewController)
final class TTProgressViewController: UIViewController {
    enum Kind {
        case diagnosis
        case download
    }

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var progressContainer: UIView?
    @IBOutlet weak var petIcon: UIImageView?
    @IBOutlet weak var progressLabel: CountingLabel?
    @IBOutlet weak var descriptionFirstLabel: UILabel?
    @IBOutlet weak var descriptionSecondLabel: UILabel?
    @IBOutlet weak var govermentIcon: UIImageView?
    @IBOutlet weak var progressUnit: UILabel?
    @IBOutlet weak var progressView: UIProgressView?
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var diagnosisImageView: UIImageView?

    private lazy var dotAnimationView = DotAnimationView()
    private lazy var downloadCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "aiscan.camera.download-progress.percent"
        return label
    }()
    private var kind: Kind = .diagnosis
    private var previewImage: UIImage?

    var isDownloadProgress: Bool { kind == .download }

    override var shouldAutorotate: Bool { false }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        titleLabel.textColor = .white
        subtitleLabel.textColor = .white
        progressLabel?.textColor = .white
        descriptionFirstLabel?.textColor = .white
        descriptionSecondLabel?.textColor = .white
        progressContainer?.backgroundColor = .clear
        progressUnit?.textColor = .white
        containerView.backgroundColor = .clear
        titleLabel.text = AIScanCameraStrings.localizedMessageKey(
            kind == .download ? "progress.download" : "progress.analyzing"
        )
        subtitleLabel.text = AIScanCameraStrings.localizedMessageKey("progress.wait")
        descriptionFirstLabel?.text = AIScanCameraStrings.localizedMessageKey("progress.medical.first")
        descriptionSecondLabel?.text = AIScanCameraStrings.localizedMessageKey("progress.medical.second")
        progressLabel?.text = "0"
        progressView?.progress = 0
        if kind == .download, let progressView {
            containerView.addSubview(downloadCountLabel)
            NSLayoutConstraint.activate([
                downloadCountLabel.topAnchor.constraint(
                    equalTo: progressView.bottomAnchor,
                    constant: 8
                ),
                downloadCountLabel.centerXAnchor.constraint(equalTo: progressView.centerXAnchor),
            ])
            downloadCountLabel.text = "0%"
        }
        diagnosisImageView?.image = previewImage
        diagnosisImageView?.accessibilityIdentifier = "aiscan.camera.progress.preview"
        progressContainer?.layer.cornerRadius = 30
        progressContainer?.clipsToBounds = true
        dotAnimationView.translatesAutoresizingMaskIntoConstraints = false
        if let progressContainer {
            progressContainer.addSubview(dotAnimationView)
            NSLayoutConstraint.activate([
                dotAnimationView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
                dotAnimationView.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
                dotAnimationView.topAnchor.constraint(equalTo: progressContainer.topAnchor),
                dotAnimationView.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            ])
        }
        let isKorean = AIScanCameraStrings.isKoreanUI()
        govermentIcon?.isHidden = !isKorean
        descriptionFirstLabel?.isHidden = !isKorean
        descriptionSecondLabel?.isHidden = !isKorean
        view.accessibilityIdentifier = kind == .download
            ? "aiscan.camera.download-progress"
            : "aiscan.camera.progress"
        progressLabel?.accessibilityIdentifier = "aiscan.camera.progress.percent"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dotAnimationView.startAnimations()
    }

    func set(progress: Double, animated: Bool = true) {
        let normalized = min(max(progress, 0), 1)
        let percentage = Int((normalized * 100).rounded())
        if animated {
            progressLabel?.update(to: percentage)
        } else {
            progressLabel?.text = "\(percentage)"
        }
        progressLabel?.accessibilityValue = "\(percentage)%"
        progressView?.setProgress(Float(normalized), animated: animated)
    }

    func set(
        downloadProgress: AIScanPreparationProgressSnapshot,
        animated: Bool = true
    ) {
        set(progress: downloadProgress.normalizedProgress, animated: animated)
        let percentage = Int((min(max(downloadProgress.normalizedProgress, 0), 1) * 100).rounded())
        downloadCountLabel.text = "\(percentage)%"
        downloadCountLabel.accessibilityValue = "\(percentage)%"
        if downloadProgress.bytesPerSecond > 0 {
            subtitleLabel.text = Self.formattedSpeed(downloadProgress.bytesPerSecond)
        }
    }

    func set(previewImage: UIImage) {
        self.previewImage = previewImage
        loadViewIfNeeded()
        diagnosisImageView?.image = previewImage
    }

    @IBAction func testButton(_ sender: Any) {}

    static func instantiate() -> TTProgressViewController {
        instantiate(identifier: "TTProgressViewController", kind: .diagnosis)
    }

    static func instantiateDownload() -> TTProgressViewController {
        instantiate(identifier: "TTProgressDownloadViewController", kind: .download)
    }

    private static func instantiate(identifier: String, kind: Kind) -> TTProgressViewController {
        guard let controller = UIStoryboard(
            name: "TTEtc",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: identifier) as? TTProgressViewController else {
            preconditionFailure("The original TTEtc progress scene is unavailable.")
        }
        controller.kind = kind
        controller.modalTransitionStyle = .crossDissolve
        controller.modalPresentationStyle = .overFullScreen
        return controller
    }

    private static func formattedSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1_024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
        if bytesPerSecond < 1_024 * 1_024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_024)
        }
        return String(format: "%.1f MB/s", bytesPerSecond / 1_024 / 1_024)
    }
}

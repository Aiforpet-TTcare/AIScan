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
        for index in 0..<dotCount {
            let angle = (CGFloat(index) / CGFloat(dotCount)) * (.pi * 2)
            let center = CGPoint(
                x: bounds.midX + cos(angle) * bounds.width * 0.34,
                y: bounds.midY + sin(angle) * bounds.height * 0.20
            )
            let dot = CAShapeLayer()
            dot.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: dotSize, height: dotSize)).cgPath
            dot.fillColor = UIColor.white.cgColor
            dot.frame = CGRect(x: center.x, y: center.y, width: dotSize, height: dotSize)
            layer.addSublayer(dot)
        }
        startAnimations()
    }

    func startAnimations() {
        layer.sublayers?.enumerated().forEach { index, layer in
            guard layer.animation(forKey: "startEndFade") == nil else { return }
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.2, 0.65, 1]
            fade.duration = 2.2
            fade.beginTime = CACurrentMediaTime() + Double(index) * 0.08
            fade.repeatCount = .infinity
            layer.add(fade, forKey: "startEndFade")
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

    override var shouldAutorotate: Bool { false }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        progressLabel?.text = "0"
        progressView?.progress = 0
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
        let isKorean = Locale.preferredLanguages.first?.hasPrefix("ko") == true
        govermentIcon?.isHidden = !isKorean
        descriptionFirstLabel?.isHidden = !isKorean
        descriptionSecondLabel?.isHidden = !isKorean
        view.accessibilityIdentifier = "aiscan.camera.progress"
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

    @IBAction func testButton(_ sender: Any) {}

    static func instantiate() -> TTProgressViewController {
        guard let controller = UIStoryboard(
            name: "TTEtc",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(withIdentifier: "TTProgressViewController") as? TTProgressViewController else {
            preconditionFailure("The original TTEtc progress scene is unavailable.")
        }
        controller.modalTransitionStyle = .crossDissolve
        controller.modalPresentationStyle = .overFullScreen
        return controller
    }
}

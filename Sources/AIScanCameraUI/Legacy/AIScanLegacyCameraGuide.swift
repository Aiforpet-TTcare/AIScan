import UIKit
@preconcurrency import WebKit
@preconcurrency import AIScanCore

enum AIScanCameraGuideURL {
    static func make(
        context: AISCScanContext,
        languageCode: String? = Locale.current.languageCode
    ) -> URL? {
        let supportedLanguage: String
        let normalizedLanguage = languageCode?.lowercased()
        switch normalizedLanguage {
        case "ko", "ja", "pt":
            supportedLanguage = normalizedLanguage ?? "en"
        default:
            supportedLanguage = "en"
        }

        let path: String
        switch context.partType {
        case .eye:
            path = context.petType == .cat ? "cat/eye" : "dog/eye"
        case .teeth:
            path = context.petType == .cat ? "cat/tooth" : "dog/tooth"
        case .skin:
            switch context.analysisPosition?.lowercased() {
            case "ear": path = "dog/ear"
            case "belly", "body": path = "dog/belly"
            case "foot", "paw": path = "dog/foot"
            default: path = "dog/skin"
            }
        default:
            return nil
        }

        return URL(
            string: "https://resource-core.aiforpetcdn.com/sdk/guide/\(supportedLanguage)/\(path).html"
        )
    }
}

enum AIScanCameraGuideNavigationPolicy {
    private static let allowedHost = "resource-core.aiforpetcdn.com"
    private static let allowedLanguages = Set(["en", "ko", "ja", "pt"])
    private static let allowedPets = Set(["dog", "cat"])
    private static let allowedPages = Set([
        "eye.html", "tooth.html", "ear.html", "belly.html", "foot.html", "skin.html",
    ])

    static func allows(_ url: URL?) -> Bool {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == allowedHost,
              components.user == nil,
              components.password == nil,
              components.port == nil || components.port == 443,
              components.query == nil,
              components.fragment == nil else {
            return false
        }

        let path = components.percentEncodedPath
        guard !path.localizedCaseInsensitiveContains("%2e") else { return false }
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard segments.count == 5,
              segments[0] == "sdk",
              segments[1] == "guide",
              allowedLanguages.contains(segments[2]),
              allowedPets.contains(segments[3]),
              allowedPages.contains(segments[4]) else {
            return false
        }
        return true
    }
}

@MainActor
@objc(TTCameraGuideViewController)
final class TTCameraGuideViewController: UIViewController {
    @IBOutlet private weak var safeAreaDummyView: UIView!
    @IBOutlet private weak var navigationContainer: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var closeButton: UIButton!

    private var url: URL?
    private var webView: WKWebView?
    var onDismiss: (() -> Void)?
    private var didNotifyDismissal = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configureWebView()
    }

    private func configureAppearance() {
        view.accessibilityIdentifier = "aiscan.camera.guide-web"
        view.backgroundColor = AIScanReferenceTheme.background
        safeAreaDummyView.backgroundColor = AIScanReferenceTheme.background
        navigationContainer.backgroundColor = AIScanReferenceTheme.background
        titleLabel.text = ""
        titleLabel.textColor = AIScanReferenceTheme.textPrimary
        let closeImage = closeButton.image(for: .normal)?.withRenderingMode(.alwaysTemplate)
        closeButton.setImage(closeImage, for: .normal)
        closeButton.tintColor = AIScanReferenceTheme.textPrimary
        closeButton.accessibilityIdentifier = "aiscan.camera.guide-web.close"
    }

    private func configureWebView() {
        guard let url, AIScanCameraGuideNavigationPolicy.allows(url) else {
            dismiss(animated: false)
            return
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = AIScanReferenceTheme.background
        webView.scrollView.backgroundColor = AIScanReferenceTheme.background
        webView.accessibilityIdentifier = "aiscan.camera.guide-web.content"
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(webView, belowSubview: navigationContainer)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: navigationContainer.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.webView = webView
        webView.load(URLRequest(url: url))
    }

    @IBAction private func close(_ sender: Any? = nil) {
        // Resume the prepared camera before the full-screen dismissal reveals
        // it, so slower devices never expose a stopped/frozen preview frame.
        notifyDismissal()
        dismiss(animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            notifyDismissal()
        }
    }

    private func notifyDismissal() {
        guard !didNotifyDismissal else { return }
        didNotifyDismissal = true
        let callback = onDismiss
        onDismiss = nil
        callback?()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }
    override var shouldAutorotate: Bool { false }

    static func instantiate(url: URL) -> TTCameraGuideViewController {
        guard let controller = UIStoryboard(
            name: "TTEtc",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(
            withIdentifier: "TTCameraGuideViewController"
        ) as? TTCameraGuideViewController else {
            preconditionFailure("The original camera guide scene is unavailable.")
        }
        controller.url = url
        controller.modalPresentationStyle = .fullScreen
        return controller
    }
}

extension TTCameraGuideViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(
            AIScanCameraGuideNavigationPolicy.allows(navigationAction.request.url)
                ? .allow
                : .cancel
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.title") { [weak self] value, _ in
            guard let title = value as? String, !title.isEmpty else { return }
            self?.titleLabel.text = title
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

extension TTCameraGuideViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url,
              AIScanCameraGuideNavigationPolicy.allows(url) else {
            return nil
        }
        webView.load(URLRequest(url: url))
        return nil
    }
}

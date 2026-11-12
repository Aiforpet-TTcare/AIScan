import UIKit
@preconcurrency import WebKit
@preconcurrency import AIScanCore

enum AIScanCameraGuideURL {
    /// Lightweight capture guide served by AI for Pet.
    static let defaultHost = "guide.ai4pet.com"
    private static let supportedLanguages: Set<String> = ["en", "ko", "ja", "th"]

    /// Returns the host-supplied guide when it is an HTTP(S) URL, otherwise the
    /// default lightweight guide for the scan context. The host app owns its
    /// guide, so its navigation is not restricted; the default guide stays on
    /// the SDK guide host.
    static func resolve(
        hostGuideURL: String?,
        context: AISCScanContext,
        languageCode: String? = Locale.current.languageCode
    ) -> AIScanCameraGuideEntry? {
        if let trimmed = hostGuideURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty,
           let url = URL(string: trimmed),
           AIScanCameraGuideNavigationPolicy.isHostSuppliedEntry(url) {
            return AIScanCameraGuideEntry(url: url, restrictsNavigation: false)
        }
        return make(context: context, languageCode: languageCode).map {
            AIScanCameraGuideEntry(url: $0, restrictsNavigation: true)
        }
    }

    static func make(
        context: AISCScanContext,
        languageCode: String? = Locale.current.languageCode
    ) -> URL? {
        let normalizedLanguage = languageCode?.lowercased() ?? "en"
        let supportedLanguage = supportedLanguages.contains(normalizedLanguage)
            ? normalizedLanguage
            : "en"

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

        return URL(string: "https://\(defaultHost)/\(supportedLanguage)/\(path)")
    }
}

/// A guide page to open and whether its navigation is limited to its host.
struct AIScanCameraGuideEntry: Equatable {
    let url: URL
    let restrictsNavigation: Bool
}

/// The SDK's default guide is display-only: it opens one HTTPS URL and stays
/// on that URL's host (cross-host navigation, redirects, and popups are
/// cancelled; non-HTTPS schemes are never loaded). A host-supplied guide URL is
/// trusted and navigates freely.
enum AIScanCameraGuideNavigationPolicy {
    static func isAcceptableEntry(_ url: URL?) -> Bool {
        origin(of: url) != nil
    }

    /// Host apps may pass any HTTP(S) page. Loading of plain HTTP still follows
    /// the host app's App Transport Security settings.
    static func isHostSuppliedEntry(_ url: URL?) -> Bool {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = components.host, !host.isEmpty else {
            return false
        }
        return true
    }

    static func allows(_ url: URL?, entry: URL) -> Bool {
        guard let candidate = origin(of: url),
              let allowed = origin(of: entry) else {
            return false
        }
        return candidate == allowed
    }

    private struct Origin: Equatable {
        let host: String
        let port: Int
    }

    private static func origin(of url: URL?) -> Origin? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.user == nil,
              components.password == nil else {
            return nil
        }
        return Origin(host: host, port: components.port ?? 443)
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
    private(set) var restrictsNavigation = true
    private var webView: WKWebView?
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    var onDismiss: (() -> Void)?
    private var didNotifyDismissal = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Guide pages are designed for a light background and may not set one
        // themselves, so the guide never inherits the camera's dark style.
        overrideUserInterfaceStyle = .light
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
        // `instantiate(url:restrictsNavigation:)` only accepts a valid entry URL.
        guard let url else { return }
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

        loadingIndicator.accessibilityIdentifier = "aiscan.camera.guide-web.loading"
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
        ])
        loadingIndicator.startAnimating()

        webView.load(URLRequest(url: url))
    }

    private func stopLoadingIndicator() {
        loadingIndicator.stopAnimating()
    }

    @IBAction private func close(_ sender: Any? = nil) {
        // Notify the camera that the guide is closing. The camera resumes
        // when its view becomes visible, respecting background and scan state.
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

    /// Returns `nil` for an entry URL the guide policy does not accept, so the
    /// camera never presents an empty guide screen.
    static func instantiate(url: URL, restrictsNavigation: Bool = true) -> TTCameraGuideViewController? {
        let accepted = restrictsNavigation
            ? AIScanCameraGuideNavigationPolicy.isAcceptableEntry(url)
            : AIScanCameraGuideNavigationPolicy.isHostSuppliedEntry(url)
        guard accepted else { return nil }
        guard let controller = UIStoryboard(
            name: "TTEtc",
            bundle: AIScanCameraResourceBundle.bundle
        ).instantiateViewController(
            withIdentifier: "TTCameraGuideViewController"
        ) as? TTCameraGuideViewController else {
            preconditionFailure("The original camera guide scene is unavailable.")
        }
        controller.url = url
        controller.restrictsNavigation = restrictsNavigation
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
        guard let entry = url else {
            decisionHandler(.cancel)
            return
        }
        guard restrictsNavigation else {
            decisionHandler(.allow)
            return
        }
        decisionHandler(
            AIScanCameraGuideNavigationPolicy.allows(navigationAction.request.url, entry: entry)
                ? .allow
                : .cancel
        )
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        stopLoadingIndicator()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        stopLoadingIndicator()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        stopLoadingIndicator()
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
        guard let entry = self.url,
              let url = navigationAction.request.url,
              !restrictsNavigation || AIScanCameraGuideNavigationPolicy.allows(url, entry: entry) else {
            return nil
        }
        webView.load(URLRequest(url: url))
        return nil
    }
}

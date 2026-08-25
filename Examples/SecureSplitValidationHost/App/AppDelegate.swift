import AIScan
import SwiftUI
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(
            rootViewController: ValidationHomeViewController()
        )
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

@MainActor
private final class ValidationActionButton: UIButton {
    var handler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(runHandler), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    @objc private func runHandler() {
        handler?()
    }
}

@MainActor
private final class ValidationHomeViewController: UIViewController {
    private struct ScanOption {
        let title: String
        let identifier: String
        let petType: PetType
        let partType: PartType
        let analysisSubpart: String?
        let analysisPosition: String?
    }

    private static let defaultScanOption = ScanOption(
        title: "DOG EYE - Right",
        identifier: "dog-eye-right",
        petType: .dog,
        partType: .eye,
        analysisSubpart: "EYER",
        analysisPosition: nil
    )

    private static let scanOptions: [ScanOption] = [
        .init(title: "DOG EYE - Left", identifier: "dog-eye-left", petType: .dog, partType: .eye, analysisSubpart: "EYEL", analysisPosition: nil),
        defaultScanOption,
        .init(title: "CAT EYE - Left", identifier: "cat-eye-left", petType: .cat, partType: .eye, analysisSubpart: "EYEL", analysisPosition: nil),
        .init(title: "CAT EYE - Right", identifier: "cat-eye-right", petType: .cat, partType: .eye, analysisSubpart: "EYER", analysisPosition: nil),
        .init(title: "DOG SKIN - Ear", identifier: "dog-skin-ear", petType: .dog, partType: .ear, analysisSubpart: nil, analysisPosition: "ear"),
        .init(title: "DOG SKIN - Belly", identifier: "dog-skin-belly", petType: .dog, partType: .belly, analysisSubpart: nil, analysisPosition: "belly"),
        .init(title: "DOG SKIN - Foot", identifier: "dog-skin-foot", petType: .dog, partType: .foot, analysisSubpart: nil, analysisPosition: "foot"),
        .init(title: "DOG TOOTH - Center", identifier: "dog-tooth-center", petType: .dog, partType: .tooth, analysisSubpart: "TCENTER", analysisPosition: nil),
        .init(title: "DOG TOOTH - Left", identifier: "dog-tooth-left", petType: .dog, partType: .tooth, analysisSubpart: "TLEFT", analysisPosition: nil),
        .init(title: "DOG TOOTH - Right", identifier: "dog-tooth-right", petType: .dog, partType: .tooth, analysisSubpart: "TRIGHT", analysisPosition: nil),
        .init(title: "CAT TOOTH - Center", identifier: "cat-tooth-center", petType: .cat, partType: .tooth, analysisSubpart: "TCENTER", analysisPosition: nil),
        .init(title: "CAT TOOTH - Left", identifier: "cat-tooth-left", petType: .cat, partType: .tooth, analysisSubpart: "TLEFT", analysisPosition: nil),
        .init(title: "CAT TOOTH - Right", identifier: "cat-tooth-right", petType: .cat, partType: .tooth, analysisSubpart: "TRIGHT", analysisPosition: nil),
    ]

    private let publishableKeyField = UITextField()
    private let appearanceControl = UISegmentedControl(items: ["System", "Light", "Dark"])
    private let statusLabel = UILabel()
    private var didRunLaunchAction = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Samsung Fire TTAPI QA"
        view.backgroundColor = .systemBackground
        configureControls()
        applyLaunchAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applySelectedAppearance()
        guard !didRunLaunchAction else { return }
        didRunLaunchAction = true

        if ProcessInfo.processInfo.arguments.contains("--show-result") {
            presentSampleResult()
        } else if ProcessInfo.processInfo.arguments.contains("--show-camera") {
            presentCamera(option: Self.defaultScanOption)
        }
    }

    private func configureControls() {
        publishableKeyField.borderStyle = .roundedRect
        publishableKeyField.placeholder = "Publishable key (not stored)"
        publishableKeyField.textContentType = .password
        publishableKeyField.autocorrectionType = .no
        publishableKeyField.autocapitalizationType = .none
        publishableKeyField.accessibilityIdentifier = "validation.publishable-key"
        let environmentKey = ProcessInfo.processInfo.environment["AISCAN_PUBLISHABLE_KEY"]
        publishableKeyField.text = environmentKey
        NSLog(
            "AIScan QA key source=%@ prefix_ok=%@ length=%ld",
            environmentKey == nil ? "missing" : "environment",
            environmentKey?.hasPrefix("tt_pk_") == true ? "yes" : "no",
            environmentKey?.count ?? 0
        )

        appearanceControl.selectedSegmentIndex = 0
        appearanceControl.accessibilityIdentifier = "validation.appearance"
        appearanceControl.addTarget(
            self,
            action: #selector(appearanceDidChange),
            for: .valueChanged
        )

        let scanButtons = Self.scanOptions.map { option in
            makeButton(
                title: option.title,
                identifier: "validation.scan.\(option.identifier)"
            ) { [weak self] in
                self?.presentCamera(option: option)
            }
        }
        let scanStack = UIStackView(arrangedSubviews: scanButtons)
        scanStack.axis = .vertical
        scanStack.spacing = 8

        let resultButton = makeButton(
            title: "Show sample result",
            identifier: "validation.show-result"
        ) { [weak self] in
            self?.presentSampleResult()
        }

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "Core and UI are loaded from the local secure-split package."
        statusLabel.accessibilityIdentifier = "validation.status"

        let stack = UIStackView(arrangedSubviews: [
            labelled("Appearance", control: appearanceControl),
            environmentNotice(),
            publishableKeyField,
            labelled("TTAPI scan targets", control: scanStack),
            resultButton,
            statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func labelled(_ title: String, control: UIView) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func environmentNotice() -> UILabel {
        let label = UILabel()
        label.text = "Samsung Test/Live routing is selected by the publishable key."
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.accessibilityIdentifier = "validation.key-environment-notice"
        return label
    }

    private func makeButton(
        title: String,
        identifier: String,
        action: @escaping @MainActor () -> Void
    ) -> UIButton {
        let button = ValidationActionButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.layer.cornerRadius = 10
        button.accessibilityIdentifier = identifier
        button.handler = action
        return button
    }

    @objc private func appearanceDidChange() {
        applySelectedAppearance()
    }

    private func applyLaunchAppearance() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "--appearance"),
              arguments.indices.contains(flagIndex + 1) else {
            return
        }

        switch arguments[flagIndex + 1].lowercased() {
        case "light":
            appearanceControl.selectedSegmentIndex = 1
        case "dark":
            appearanceControl.selectedSegmentIndex = 2
        default:
            appearanceControl.selectedSegmentIndex = 0
        }
        applySelectedAppearance()
    }

    private func applySelectedAppearance() {
        let style: UIUserInterfaceStyle
        switch appearanceControl.selectedSegmentIndex {
        case 1:
            style = .light
        case 2:
            style = .dark
        default:
            style = .unspecified
        }
        view.window?.overrideUserInterfaceStyle = style
    }

    private func presentCamera(option: ScanOption) {
        let key = publishableKeyField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            statusLabel.text = "Enter AISCAN_PUBLISHABLE_KEY in the scheme environment or field."
            return
        }

        NSLog(
            "AIScan QA scan key prefix_ok=%@ length=%ld",
            key.hasPrefix("tt_pk_") ? "yes" : "no",
            key.count
        )

        // Test and Live are key/project properties on the public SDK gateway;
        // `development` is intentionally fail-closed for remote Core traffic.
        AIScanManager.configure(publishableKey: key, environment: .production)
        statusLabel.text = "Starting \(option.title)..."
        let startedAt = Date()

        do {
            try AIScanManager.showCamera(
                petType: option.petType,
                partType: option.partType,
                on: self,
                analysisSubpart: option.analysisSubpart,
                analysisPosition: option.analysisPosition,
                petId: "secure-split-device-validation",
                completion: { [weak self] result in
                    let elapsed = Date().timeIntervalSince(startedAt)
                    switch result {
                    case let .success(scanResult):
                        let contractStatus = scanResult.contractResult?.payload["status"] as? String
                        self?.statusLabel.text = String(
                            format: "%@ completed in %.2fs. contract status: %@",
                            option.title,
                            elapsed,
                            contractStatus ?? "missing"
                        )
                    case let .failure(error):
                        let nsError = error as NSError
                        let reason = nsError.userInfo[AISCDisplayReasonKey] as? String
                            ?? "missing"
                        NSLog(
                            "AIScan QA failure domain=%@ code=%ld reason=%@",
                            nsError.domain,
                            nsError.code,
                            reason
                        )
                        self?.statusLabel.text = String(
                            format: "%@ failed in %.2fs: %@",
                            option.title,
                            elapsed,
                            error.localizedDescription
                        )
                    }
                }
            )
        } catch {
            statusLabel.text = error.localizedDescription
        }
    }

    private func presentSampleResult() {
        let locale = Locale.preferredLanguages.first ?? "en"
        let detailRows: [AIScanDisplayDetailRowViewModel]
        let symptomNames: (tear: String, thirdEyelid: String, chemosis: String)
        if locale.hasPrefix("ko") {
            symptomNames = ("유루증", "제3안검돌출증", "결막부종")
            detailRows = [
                .init(
                    text: "<b>이 증상은 무엇인가요</b><br>눈물이 과도하게 흘러 눈 주변이 계속 젖어 있는 상태예요. 눈 주변 털이 갈색이나 붉게 변할 수 있어요.",
                    iconName: "vuesaxBoldMessageNotif"
                ),
                .init(
                    text: "<b>관련 질환 및 요인</b><br>각막염<br>결막염<br>비루관 폐색<br>안검내반",
                    iconName: "iconPageClipboardTick"
                ),
                .init(
                    text: "<b>홈케어 시 주의사항</b><br>눈 주변을 깨끗하게 관리해 주세요.",
                    iconName: "iconPageDanger"
                )
            ]
        } else if locale.hasPrefix("ja") {
            symptomNames = ("流涙症", "第三眼瞼突出", "結膜浮腫")
            detailRows = [
                .init(text: "<b>この症状は何ですか？</b><br>涙が多く、目の周りが濡れ続ける状態です。", iconName: "vuesaxBoldMessageNotif"),
                .init(text: "<b>関連する疾患と要因</b><br>角膜炎<br>結膜炎<br>鼻涙管閉塞", iconName: "iconPageClipboardTick"),
                .init(text: "<b>ホームケアの注意事項</b><br>目の周りを清潔に保ってください。", iconName: "iconPageDanger")
            ]
        } else {
            symptomNames = ("Epiphora", "Third eyelid protrusion", "Chemosis")
            detailRows = [
                .init(text: "<b>What is this symptom?</b><br>Excess tears keep the area around the eye wet.", iconName: "vuesaxBoldMessageNotif"),
                .init(text: "<b>Related conditions and factors</b><br>Keratitis<br>Conjunctivitis<br>Blocked tear duct", iconName: "iconPageClipboardTick"),
                .init(text: "<b>Home-care precautions</b><br>Keep the area around the eye clean.", iconName: "iconPageDanger")
            ]
        }

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .gregorian)
        dateComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        dateComponents.year = 2026
        dateComponents.month = 7
        dateComponents.day = 15
        dateComponents.hour = 10
        dateComponents.minute = 4

        let viewModel = AIScanDisplayResultViewModel(
            status: "CAUTION",
            diagnosisID: "device-visual-audit",
            symptoms: [
                AIScanDisplaySymptomViewModel(
                    id: "tear",
                    code: "tear",
                    name: symptomNames.tear,
                    abnormalLevel: 2,
                    resultLabel: "주의 깊은 관찰이 필요해요",
                    detailRows: detailRows
                ),
                AIScanDisplaySymptomViewModel(
                    id: "third-eyelid",
                    code: "third-eyelid",
                    name: symptomNames.thirdEyelid,
                    resultLabel: "관찰되지 않아요",
                    detailRows: detailRows
                ),
                AIScanDisplaySymptomViewModel(
                    id: "chemosis",
                    code: "chemosis",
                    name: symptomNames.chemosis,
                    resultLabel: "관찰되지 않아요",
                    detailRows: detailRows
                ),
            ],
            analyzedAt: dateComponents.date ?? Date()
        )
        let controller = AIScanResultViewController.instance(viewModel: viewModel)
        controller.onClose = { [weak controller] in controller?.dismiss(animated: true) }
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }
}

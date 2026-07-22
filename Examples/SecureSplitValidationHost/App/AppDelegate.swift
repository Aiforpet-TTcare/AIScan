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
private final class ValidationHomeViewController: UIViewController {
    private let publishableKeyField = UITextField()
    private let environmentControl = UISegmentedControl(items: ["Production", "Development"])
    private let appearanceControl = UISegmentedControl(items: ["System", "Light", "Dark"])
    private let statusLabel = UILabel()
    private var didRunLaunchAction = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Secure Split QA"
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
        }
    }

    private func configureControls() {
        publishableKeyField.borderStyle = .roundedRect
        publishableKeyField.placeholder = "Publishable key (not stored)"
        publishableKeyField.textContentType = .password
        publishableKeyField.autocorrectionType = .no
        publishableKeyField.autocapitalizationType = .none
        publishableKeyField.accessibilityIdentifier = "validation.publishable-key"
        publishableKeyField.text = ProcessInfo.processInfo.environment["AISCAN_PUBLISHABLE_KEY"]

        environmentControl.selectedSegmentIndex = 0
        environmentControl.accessibilityIdentifier = "validation.environment"

        appearanceControl.selectedSegmentIndex = 0
        appearanceControl.accessibilityIdentifier = "validation.appearance"
        appearanceControl.addAction(UIAction { [weak self] _ in
            self?.applySelectedAppearance()
        }, for: .valueChanged)

        let cameraButton = makeButton(
            title: "Present camera",
            identifier: "validation.show-camera"
        ) { [weak self] in
            self?.presentCamera()
        }
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
            labelled("Environment", control: environmentControl),
            publishableKeyField,
            cameraButton,
            resultButton,
            statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
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

    private func makeButton(
        title: String,
        identifier: String,
        action: @escaping @MainActor () -> Void
    ) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .large

        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
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

    private func presentCamera() {
        let key = publishableKeyField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            statusLabel.text = "Enter AISCAN_PUBLISHABLE_KEY in the scheme environment or field."
            return
        }

        let environment: AISCEnvironment = environmentControl.selectedSegmentIndex == 1
            ? .development
            : .production
        AIScanManager.configure(publishableKey: key, environment: environment)

        do {
            try AIScanManager.showCamera(
                petType: .dog,
                partType: .eye,
                on: self,
                petId: "secure-split-device-validation",
                completion: { [weak self] result in
                    self?.statusLabel.text = String(describing: result)
                }
            )
        } catch {
            statusLabel.text = error.localizedDescription
        }
    }

    private func presentSampleResult() {
        let viewModel = AIScanDisplayResultViewModel(
            status: "관찰이 필요해요",
            diagnosisID: "device-visual-audit",
            symptoms: [
                AIScanDisplaySymptomViewModel(
                    id: "tear",
                    code: "tear",
                    name: "유루증",
                    abnormalLevel: 2,
                    resultLabel: "주의 깊은 관찰이 필요해요"
                ),
                AIScanDisplaySymptomViewModel(
                    id: "third-eyelid",
                    code: "third-eyelid",
                    name: "제3안검돌출증",
                    resultLabel: "관찰되지 않아요"
                ),
                AIScanDisplaySymptomViewModel(
                    id: "chemosis",
                    code: "chemosis",
                    name: "결막부종",
                    resultLabel: "관찰되지 않아요"
                ),
            ]
        )
        let controller = UIHostingController(
            rootView: AIScanResultReferenceView(viewModel: viewModel)
        )
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak controller] _ in
                controller?.dismiss(animated: true)
            }
        )

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }
}

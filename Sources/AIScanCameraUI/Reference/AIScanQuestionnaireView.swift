import SwiftUI
@preconcurrency import AIScanCore

enum AIScanQuestionnairePresentationState: Equatable {
    case loading
    case answering
    case submitting
}

@MainActor
final class AIScanQuestionnaireViewModel: ObservableObject {
    @Published private(set) var currentIndex = 0
    @Published private(set) var answers: [Bool?]
    @Published private(set) var isSubmitting = false

    let prompts: [AISCQuestionnairePrompt]
    private let onComplete: ([AISCQuestionnaireAnswer]) -> Void
    private var didComplete = false

    init(
        prompts: [AISCQuestionnairePrompt],
        onComplete: @escaping ([AISCQuestionnaireAnswer]) -> Void
    ) {
        self.prompts = prompts
        answers = Array(repeating: nil, count: prompts.count)
        self.onComplete = onComplete
    }

    var currentPrompt: AISCQuestionnairePrompt? {
        guard prompts.indices.contains(currentIndex) else { return nil }
        return prompts[currentIndex]
    }

    var presentationState: AIScanQuestionnairePresentationState {
        if prompts.isEmpty { return .loading }
        return isSubmitting ? .submitting : .answering
    }

    func moveBack() {
        guard !isSubmitting, currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func answerCurrentQuestion(positive: Bool) {
        guard !isSubmitting, prompts.indices.contains(currentIndex) else { return }
        answers[currentIndex] = positive
        guard currentIndex == prompts.count - 1 else {
            currentIndex += 1
            return
        }
        finish()
    }

    private func finish() {
        guard !didComplete else { return }
        didComplete = true
        isSubmitting = true
        let completed = zip(prompts, answers).map { prompt, answer in
            AISCQuestionnaireAnswer(prompt: prompt, positive: answer ?? false)
        }
        onComplete(completed)
    }
}

@MainActor
struct AIScanQuestionnaireView: View {
    @ObservedObject var viewModel: AIScanQuestionnaireViewModel

    private let transition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    var body: some View {
        ZStack {
            Color(AIScanQuestionnaireTheme.background)
                .edgesIgnoringSafeArea(.all)

            if viewModel.presentationState == .loading {
                activityIndicator
            } else {
                VStack(spacing: 40) {
                    header
                    linearProgress

                    Spacer()
                    question
                    Spacer()
                    answerButtons
                }
            }
        }
        .accessibilityElement(children: .contain)
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private var activityIndicator: some View {
        if #available(iOS 14.0, *) {
            ProgressView()
                .progressViewStyle(
                    CircularProgressViewStyle(
                        tint: Color(AIScanQuestionnaireTheme.accent)
                    )
                )
        } else {
            AIScanQuestionnaireActivityIndicator(
                color: AIScanQuestionnaireTheme.accent
            )
        }
    }

    @ViewBuilder
    private var linearProgress: some View {
        if #available(iOS 14.0, *) {
            ProgressView(
                value: Double(viewModel.currentIndex + 1),
                total: Double(viewModel.prompts.count)
            )
            .progressViewStyle(
                LinearProgressViewStyle(
                    tint: Color(AIScanQuestionnaireTheme.accent)
                )
            )
            .padding(.horizontal)
        } else {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Color(UIColor.systemGray5)
                    Color(AIScanQuestionnaireTheme.accent)
                        .frame(
                            width: geometry.size.width
                                * CGFloat(viewModel.currentIndex + 1)
                                / CGFloat(max(viewModel.prompts.count, 1))
                        )
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
        }
    }

    private var header: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.moveBack()
                }
            }) {
                Image(systemName: "chevron.left")
                    .renderingMode(.template)
                    .font(.system(size: 20))
                    .foregroundColor(
                        viewModel.currentIndex > 0
                            ? Color(AIScanQuestionnaireTheme.textPrimary)
                            : .clear
                    )
            }
            .disabled(viewModel.currentIndex == 0)

            Spacer()

            Text("\(viewModel.currentIndex + 1) / \(viewModel.prompts.count)")
                .font(.custom("AppleSDGothicNeo-Medium", size: 16))
                .foregroundColor(Color(AIScanQuestionnaireTheme.textSecondary))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 20))
                .foregroundColor(.clear)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private var question: some View {
        ZStack {
            ForEach(viewModel.prompts.indices, id: \.self) { index in
                if index == viewModel.currentIndex {
                    VStack(spacing: 24) {
                        Image(
                            "stethoscope",
                            bundle: AIScanCameraResourceBundle.bundle
                        )
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(
                            Color(AIScanQuestionnaireTheme.accent).opacity(0.8)
                        )

                        Text(viewModel.prompts[index].text)
                            .font(.custom("AppleSDGothicNeo-Bold", size: 24))
                            .foregroundColor(Color(AIScanQuestionnaireTheme.textPrimary))
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                            .padding(.horizontal, 24)
                    }
                    .transition(transition)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 250)
    }

    private var answerButtons: some View {
        HStack(spacing: 20) {
            answerButton(
                title: AIScanCameraStrings.localizedMessageKey("questionnaire.no"),
                positive: false,
                foreground: Color(AIScanQuestionnaireTheme.textSecondary),
                activityColor: AIScanQuestionnaireTheme.textSecondary,
                background: Color(AIScanQuestionnaireTheme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(AIScanQuestionnaireTheme.subtleBorder), lineWidth: 1)
            )

            answerButton(
                title: AIScanCameraStrings.localizedMessageKey("questionnaire.yes"),
                positive: true,
                foreground: Color(AIScanQuestionnaireTheme.onBrand),
                activityColor: AIScanQuestionnaireTheme.onBrand,
                background: Color(AIScanQuestionnaireTheme.accent)
            )
            .shadow(
                color: Color(AIScanQuestionnaireTheme.softShadow),
                radius: 8,
                y: 4
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    private func answerButton(
        title: String,
        positive: Bool,
        foreground: Color,
        activityColor: UIColor,
        background: Color
    ) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.answerCurrentQuestion(positive: positive)
            }
        }) {
            ZStack {
                Text(title)
                    .font(.custom("AppleSDGothicNeo-Bold", size: 18))
                    .foregroundColor(viewModel.isSubmitting ? .clear : foreground)
                if viewModel.isSubmitting {
                    questionnaireActivityIndicator(
                        color: foreground,
                        uiColor: activityColor
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isSubmitting)
        .accessibility(label: Text(title))
    }

    @ViewBuilder
    private func questionnaireActivityIndicator(
        color: Color,
        uiColor: UIColor
    ) -> some View {
        if #available(iOS 14.0, *) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: color))
        } else {
            AIScanQuestionnaireActivityIndicator(color: uiColor)
        }
    }
}

/// Validation-only factory used by the private integration host to exercise the
/// real questionnaire surface without manufacturing a network diagnosis.
/// Regular SDK clients receive this surface from the Core-owned scan workflow.
@_spi(AIScanValidation)
@MainActor
public enum AIScanQuestionnairePreviewFactory {
    public static func makeViewController(
        prompts: [String],
        onComplete: @escaping ([Bool]) -> Void
    ) -> UIViewController {
        let corePrompts = prompts.enumerated().map { index, text in
            AISCQuestionnairePrompt(
                identifier: "validation-question-\(index + 1)",
                text: text
            )
        }
        let viewModel = AIScanQuestionnaireViewModel(prompts: corePrompts) { answers in
            onComplete(answers.map(\.positive))
        }
        let controller = UIHostingController(
            rootView: AIScanQuestionnaireView(viewModel: viewModel)
        )
        controller.view.accessibilityIdentifier = "aiscan.questionnaire"
        controller.modalPresentationStyle = .fullScreen
        return controller
    }
}

private struct AIScanQuestionnaireActivityIndicator: UIViewRepresentable {
    let color: UIColor

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = color
        indicator.startAnimating()
        return indicator
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.color = color
        if !uiView.isAnimating {
            uiView.startAnimating()
        }
    }
}

private enum AIScanQuestionnaireTheme {
    static var background: UIColor { adaptive(light: .white, dark: .systemBackground) }
    static var surfaceSecondary: UIColor {
        adaptive(light: rgb(0xF5F6F8), dark: .tertiarySystemBackground)
    }
    static var textPrimary: UIColor { adaptive(light: rgb(0x191919), dark: .label) }
    static var textSecondary: UIColor { adaptive(light: rgb(0x717171), dark: .secondaryLabel) }
    static var subtleBorder: UIColor {
        adaptive(light: .black.withAlphaComponent(0.06), dark: .separator)
    }
    static var softShadow: UIColor {
        adaptive(
            light: .black.withAlphaComponent(0.08),
            dark: .black.withAlphaComponent(0.35)
        )
    }
    static var accent: UIColor {
        UIColor(
            named: "AISBrandAccent",
            in: AIScanCameraResourceBundle.bundle,
            compatibleWith: nil
        ) ?? .systemBlue
    }
    static var onBrand: UIColor {
        UIColor(
            named: "AISOnBrand",
            in: AIScanCameraResourceBundle.bundle,
            compatibleWith: nil
        ) ?? .white
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            (traits.userInterfaceStyle == .dark ? dark : light)
                .resolvedColor(with: traits)
        }
    }

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

import UIKit
@preconcurrency import AIScanCore

/// One terminal outcome in the user's selected photo order.
public struct AIScanMultiPhotoOutcome: @unchecked Sendable {
    public let photoID: String
    public let photoIndex: Int
    public let result: AISCDisplayResult?
    public let error: Error?
    public let errorMessage: String?
    public let analysisSubpart: String?
    public let analysisPosition: String?
}

@MainActor
final class AIScanMultiPhotoJob: NSObject, AIScanCameraControllerDelegate {
    enum Phase { case uploading, ready, analyzing, finished }
    let id = UUID().uuidString
    let preview: UIImage
    let context: AISCScanContext
    let controller: AIScanCameraController
    private(set) var phase: Phase = .uploading
    private(set) var progress: Double = 0
    private(set) var outcome: Result<AISCDisplayResult, Error>?
    var onChange: (() -> Void)?
    var onQuestionnaire: ((AISCQuestionnaire) -> Void)?
    private var input: AISCImageInput?
    private var uploadedPhoto: AISCUploadedPhoto?
    private var analysisRequested = false
    private var cancelled = false

    init(input: AISCImageInput, preview: UIImage, context: AISCScanContext, controller: AIScanCameraController) {
        self.input = input
        self.preview = preview
        self.context = context
        self.controller = controller
        super.init()
        controller.delegate = self
    }

    func upload() {
        guard !cancelled, let input else { return }
        controller.prepare(context: context) { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.cancelled else { return }
                if let error { self.finish(.failure(error)); return }
                guard self.controller.analysisMode == AISCAnalysisMode(rawValue: 1) else {
                    self.finish(.failure(AIScanMultiPhotoError.requiresTTAPI))
                    return
                }
                self.controller.uploadPhoto(input, progress: { [weak self] value in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, !self.cancelled else { return }
                        self.progress = max(self.progress, min(max(value, 0), 1) * 0.15)
                        self.onChange?()
                    }
                }, completion: { [weak self] photo, error in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, !self.cancelled else { return }
                        guard let photo, error == nil else {
                            self.finish(.failure(error ?? AIScanCameraControllerError.emptyDiagnosisResult))
                            return
                        }
                        self.uploadedPhoto = photo
                        self.input = nil
                        self.phase = .ready
                        self.progress = 0.15
                        self.onChange?()
                        self.beginAnalysisIfReady()
                    }
                })
            }
        }
    }

    func requestAnalysis() {
        guard !cancelled else { return }
        analysisRequested = true
        beginAnalysisIfReady()
    }

    private func beginAnalysisIfReady() {
        guard analysisRequested, !cancelled, phase == .ready, let uploadedPhoto else { return }
        phase = .analyzing
        onChange?()
        controller.diagnoseUploadedPhoto(uploadedPhoto)
    }

    func cancel() {
        cancelled = true
        onChange = nil
        onQuestionnaire = nil
        controller.delegate = nil
        controller.cancel()
        uploadedPhoto = nil
        input = nil
    }

    private func finish(_ result: Result<AISCDisplayResult, Error>) {
        guard !cancelled, outcome == nil else { return }
        outcome = result
        phase = .finished
        progress = 1
        uploadedPhoto = nil
        input = nil
        onChange?()
    }

    func aiscanCameraController(_ controller: AIScanCameraController, didUpdate evaluation: AISCFrameEvaluation) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didCapture evaluation: AISCFrameEvaluation) {}
    func aiscanCameraController(_ controller: AIScanCameraController, didUpdateDiagnosisProgress value: Double) {
        guard !cancelled, phase == .analyzing else { return }
        progress = max(progress, 0.15 + min(max(value, 0), 1) * 0.85)
        onChange?()
    }
    func aiscanCameraController(_ controller: AIScanCameraController, didRequest questionnaire: AISCQuestionnaire) {
        guard !cancelled else { return }
        onQuestionnaire?(questionnaire)
    }
    func aiscanCameraController(_ controller: AIScanCameraController, didProduce result: AISCDisplayResult) {
        finish(.success(result))
    }
    func aiscanCameraController(_ controller: AIScanCameraController, didFail error: Error) {
        finish(.failure(error))
    }
}

@MainActor
final class AIScanMultiPhotoCoordinator {
    private(set) var items: [AIScanMultiPhotoJob] = []
    private(set) var isAnalyzing = false
    private var cancelled = false
    private var completed = false
    private let makeController: () -> AIScanCameraController
    var onChange: (() -> Void)?
    var onComplete: (([AIScanMultiPhotoOutcome]) -> Void)?
    var onQuestionnaire: ((AISCQuestionnaire, @escaping ([AISCQuestionnaireAnswer]) -> Void) -> Void)?
    private var answerCache: [String: [String: Bool]] = [:]
    private var questionGroups: [(String, AISCQuestionnaire)] = []
    private var questionWaiters: [String: [(AIScanMultiPhotoJob, AISCQuestionnaire)]] = [:]
    private var showingQuestionnaire = false

    init(makeController: @escaping () -> AIScanCameraController) { self.makeController = makeController }
    var canAdd: Bool { !cancelled && !isAnalyzing && items.count < 4 }
    var completedCount: Int { items.filter { $0.outcome != nil }.count }
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        let value = items.reduce(0) { $0 + $1.progress } / Double(items.count)
        return completed ? 1 : min(value, 0.99)
    }

    @discardableResult
    func append(input: AISCImageInput, preview: UIImage, context: AISCScanContext) -> Bool {
        guard canAdd else { return false }
        let job = AIScanMultiPhotoJob(input: input, preview: Self.thumbnail(preview),
                                     context: Self.copyContext(context), controller: makeController())
        job.onChange = { [weak self] in self?.changed() }
        job.onQuestionnaire = { [weak self, weak job] questionnaire in
            guard let self, let job else { return }
            self.requestQuestionnaire(questionnaire, for: job)
        }
        items.append(job)
        onChange?()
        job.upload()
        return true
    }

    func remove(id: String) {
        guard !isAnalyzing, let index = items.firstIndex(where: { $0.id == id }) else { return }
        let job = items.remove(at: index)
        job.cancel()
        onChange?()
    }

    func analyze() {
        guard !cancelled, !isAnalyzing, !items.isEmpty else { return }
        isAnalyzing = true
        onChange?()
        // Each photo owns a prepared Core session. Start every ready photo now;
        // a still-uploading photo joins as soon as its own upload completes.
        items.forEach { $0.requestAnalysis() }
        changed()
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        items.forEach { $0.cancel() }
        items.removeAll()
        answerCache.removeAll()
        questionGroups.removeAll()
        questionWaiters.removeAll()
        onChange = nil
        onComplete = nil
        onQuestionnaire = nil
    }

    private func changed() {
        guard !cancelled, !completed else { return }
        onChange?()
        guard isAnalyzing, items.allSatisfy({ $0.outcome != nil }) else { return }
        completed = true
        let outcomes = items.enumerated().map { index, item -> AIScanMultiPhotoOutcome in
            let result: AISCDisplayResult?
            let error: Error?
            switch item.outcome! {
            case let .success(value): result = value; error = nil
            case let .failure(value): result = nil; error = value
            }
            return AIScanMultiPhotoOutcome(photoID: item.id, photoIndex: index + 1,
                result: result, error: error,
                errorMessage: error.map { AIScanCameraStrings.displayMessage(for: $0) }
                    ?? (result?.requiresRetake == true ? AIScanCameraStrings.retakeMessage(
                        for: result?.retakeReasonCode, partType: item.context.partType,
                        analysisPosition: item.context.analysisPosition, isAlbum: true) : nil),
                analysisSubpart: item.context.analysisSubpart ?? item.context.displaySubpart,
                analysisPosition: item.context.analysisPosition)
        }
        onComplete?(outcomes)
    }

    private func requestQuestionnaire(_ questionnaire: AISCQuestionnaire, for job: AIScanMultiPhotoJob) {
        let signature = questionnaire.prompts.map(\.identifier).joined(separator: "|")
        if let cached = answerCache[signature] {
            job.controller.submitQuestionnaireAnswers(questionnaire.prompts.map {
                AISCQuestionnaireAnswer(prompt: $0, positive: cached[$0.identifier] ?? false)
            })
            return
        }
        if questionWaiters[signature] == nil { questionGroups.append((signature, questionnaire)) }
        questionWaiters[signature, default: []].append((job, questionnaire))
        presentNextQuestionnaire()
    }

    private func presentNextQuestionnaire() {
        guard !cancelled, !completed, !showingQuestionnaire,
              let (signature, questionnaire) = questionGroups.first else { return }
        showingQuestionnaire = true
        onQuestionnaire?(questionnaire) { [weak self] answers in
            guard let self, !self.cancelled else { return }
            let cached = Dictionary(uniqueKeysWithValues: answers.map { ($0.prompt.identifier, $0.positive) })
            self.answerCache[signature] = cached
            let waiters = self.questionWaiters.removeValue(forKey: signature) ?? []
            for (job, prompts) in waiters {
                job.controller.submitQuestionnaireAnswers(prompts.prompts.map {
                    AISCQuestionnaireAnswer(prompt: $0, positive: cached[$0.identifier] ?? false)
                })
            }
            self.questionGroups.removeAll { $0.0 == signature }
            self.showingQuestionnaire = false
            self.presentNextQuestionnaire()
        }
    }

    static func copyContext(_ source: AISCScanContext) -> AISCScanContext {
        let copy = AISCScanContext()
        copy.petType = source.petType
        copy.partType = source.partType
        copy.displaySubpart = source.displaySubpart
        copy.analysisSubpart = source.analysisSubpart
        copy.analysisPosition = source.analysisPosition
        copy.petIdentifier = source.petIdentifier
        copy.userIdentifier = source.userIdentifier
        copy.recordIdentifier = source.recordIdentifier
        copy.displayMetadata = source.displayMetadata
        copy.questionnaireEnabled = source.questionnaireEnabled
        return copy
    }

    private static func thumbnail(_ source: UIImage) -> UIImage {
        let scale = min(1, 900 / max(source.size.width, source.size.height))
        let size = CGSize(width: max(1, source.size.width * scale), height: max(1, source.size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum AIScanMultiPhotoError: LocalizedError {
    case requiresTTAPI
    var errorDescription: String? { AIScanCameraStrings.localizedMessageKey("multi.requires_ttapi") }
}

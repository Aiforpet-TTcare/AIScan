import SwiftUI
import AIScanCore

public struct AIScanResultReferenceView: UIViewControllerRepresentable {
    private let viewModel: AIScanDisplayResultViewModel
    private let onClose: (() -> Void)?

    public init(
        viewModel: AIScanDisplayResultViewModel,
        onClose: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public init(result: AISCDisplayResult, onClose: (() -> Void)? = nil) {
        self.init(viewModel: AIScanDisplayResultViewModel(result: result), onClose: onClose)
    }

    public func makeUIViewController(context: Context) -> AIScanResultViewController {
        AIScanResultViewController.instance(viewModel: viewModel, onClose: onClose)
    }

    public func updateUIViewController(
        _ uiViewController: AIScanResultViewController,
        context: Context
    ) {
        uiViewController.onClose = onClose
        uiViewController.apply(viewModel: viewModel)
    }
}

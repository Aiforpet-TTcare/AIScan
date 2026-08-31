import SwiftUI
import AIScanCore

public struct AIScanResultReferenceView: UIViewControllerRepresentable {
    private let viewModel: AIScanDisplayResultViewModel
    private let onClose: (() -> Void)?
    private let onExportReport: (() -> Void)?

    public init(
        viewModel: AIScanDisplayResultViewModel,
        onClose: (() -> Void)? = nil,
        onExportReport: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.onExportReport = onExportReport
    }

    public init(
        result: AISCDisplayResult,
        onClose: (() -> Void)? = nil,
        onExportReport: (() -> Void)? = nil
    ) {
        self.init(
            viewModel: AIScanDisplayResultViewModel(result: result),
            onClose: onClose,
            onExportReport: onExportReport
        )
    }

    public func makeUIViewController(context: Context) -> AIScanResultViewController {
        AIScanResultViewController.instance(
            viewModel: viewModel,
            onClose: onClose,
            onExportReport: onExportReport
        )
    }

    public func updateUIViewController(
        _ uiViewController: AIScanResultViewController,
        context: Context
    ) {
        uiViewController.onClose = onClose
        uiViewController.onExportReport = onExportReport
        uiViewController.apply(viewModel: viewModel)
    }
}

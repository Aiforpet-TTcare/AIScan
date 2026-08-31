import SwiftUI
import UIKit

@_spi(AIScanLifecycle)
public enum AIScanPDFReportError: Error, Equatable {
    case renderFailed
    case exportInProgress
}

enum AIScanPDFReportGenerator {
    @discardableResult
    static func generate(_ input: AIScanPDFReportInput) async throws -> URL {
        FontRegistrar.registerIfNeeded()
        let props = DiagnosisPdfAdapter.makeProps(from: input)
        let images = await PDFImageLoader().preload(props)
        let resolved = PDFResolvedImages(images: images)
        let url = try await MainActor.run { () throws -> URL in
            let pages = buildPages(props: props, resolved: resolved)
            let outputURL = destinationURL(for: props)
            guard let saved = PDFExporter.export(pages: pages, to: outputURL) else {
                throw AIScanPDFReportError.renderFailed
            }
            return saved
        }
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        return url
    }

    @MainActor
    private static func buildPages(
        props: ScreeningPdfProps,
        resolved: PDFResolvedImages
    ) -> [any View] {
        let placed =
            PDFPaginator.pack(
                title: PDFStrings.layoutSummaryTitle,
                blocks: PDFSummaryView(props: props, resolved: resolved).blocks()
            )
            + PDFPaginator.pack(
                title: PDFStrings.layoutDetailTitle,
                blocks: PDFDetailView(props: props, resolved: resolved).blocks()
            )
            + PDFPaginator.pack(
                title: PDFStrings.layoutComprehensiveTitle,
                blocks: PDFComprehensiveView(props: props).blocks()
            )
        let total = 1 + placed.count
        var pages: [any View] = [PDFCoverView(props: props)]
        for (index, page) in placed.enumerated() {
            pages.append(
                PDFBlockPageView(
                    part: props.part,
                    page: page,
                    pageNumber: index + 2,
                    totalPages: total
                )
            )
        }
        return pages
    }

    private static func destinationURL(for props: ScreeningPdfProps) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches.appendingPathComponent("com.ttcare.reports", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let part = props.part.isEmpty ? "REPORT" : props.part
        return directory.appendingPathComponent("TTcare-Report-\(part).pdf")
    }
}

@_spi(AIScanLifecycle)
@MainActor
public final class AIScanPDFExportCoordinator {
    private var isGenerating = false

    public init() {}

    public func generate(
        _ input: AIScanPDFReportInput
    ) async -> Result<URL, Error> {
        guard !isGenerating else {
            return .failure(AIScanPDFReportError.exportInProgress)
        }
        isGenerating = true
        defer { isGenerating = false }
        do {
            return .success(try await AIScanPDFReportGenerator.generate(input))
        } catch {
            return .failure(error)
        }
    }
}

@_spi(AIScanLifecycle)
@MainActor
public enum AIScanPDFSharePresenter {
    @discardableResult
    public static func present(
        fileURL: URL,
        from viewController: UIViewController
    ) -> Bool {
        let presenter = topmostViewController(from: viewController)
        guard presenter.presentedViewController == nil else { return false }
        let activity = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        if let popover = activity.popoverPresentationController {
            let anchor = presenter.viewIfLoaded ?? viewController.view
            popover.sourceView = anchor
            popover.sourceRect = CGRect(
                x: anchor?.bounds.midX ?? 0,
                y: (anchor?.bounds.maxY ?? 0) - 40,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
        return true
    }

    public static func showFailure(from viewController: UIViewController) {
        let presenter = topmostViewController(from: viewController)
        guard let window = presenter.viewIfLoaded?.window else { return }
        window.viewWithTag(toastTag)?.removeFromSuperview()

        let toast = UIView()
        toast.tag = toastTag
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        toast.layer.cornerRadius = 21
        toast.alpha = 0

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = PDFStrings.exportFailedToast
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        toast.addSubview(label)
        window.addSubview(toast)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: toast.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -10),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -16),
            toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 42),
        ])
        UIView.animate(withDuration: 0.5) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            UIView.animate(withDuration: 0.5, animations: {
                toast.alpha = 0
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        }
    }

    private static let toastTag = 0xA15C_A11

    private static func topmostViewController(
        from root: UIViewController
    ) -> UIViewController {
        var top = root
        while let presented = top.presentedViewController,
              !(presented is UIActivityViewController) {
            top = presented
        }
        if let navigation = top as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topmostViewController(from: visible)
        }
        if let tab = top as? UITabBarController,
           let selected = tab.selectedViewController {
            return topmostViewController(from: selected)
        }
        return top
    }
}

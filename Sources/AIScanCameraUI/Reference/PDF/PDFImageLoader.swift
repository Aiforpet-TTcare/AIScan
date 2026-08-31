import UIKit
@preconcurrency import AIScanCore

actor PDFImageLoader {
    private var cache: [URL: UIImage] = [:]

    func image(for url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let cached = cache[url] { return cached }
        let data = await Self.loadData(from: url)
        guard let data, let image = UIImage(data: data) else { return nil }
        cache[url] = image
        return image
    }

    func preload(_ props: ScreeningPdfProps) async -> [URL: UIImage] {
        var urls: [URL] = []
        urls.append(contentsOf: props.diagnoses.positions.compactMap(\.cropImageUrl))
        for symptom in props.diagnoses.symptoms {
            for origin in symptom.origin {
                if let url = origin.camImageUrl { urls.append(url) }
                if let url = origin.capturedImageUrl { urls.append(url) }
            }
        }
        let missing = Set(urls).filter { cache[$0] == nil }
        await withTaskGroup(of: (URL, Data?).self) { group in
            for url in missing {
                group.addTask {
                    (url, await Self.loadData(from: url))
                }
            }
            for await (url, data) in group {
                guard let data, let image = UIImage(data: data) else { continue }
                cache[url] = image
            }
        }
        return cache
    }

    private nonisolated static func loadData(from url: URL) async -> Data? {
        await withCheckedContinuation { continuation in
            AISCDisplayAssetLoader.loadData(from: url) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

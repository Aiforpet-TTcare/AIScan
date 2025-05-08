// swift-tools-version: 6.1
// tag: "1.0.11"
import PackageDescription

let package = Package(
    name: "AIScan",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // 외부에는 이 wrapper 라이브러리만 노출
        .library(
            name: "AIScan",
            targets: ["AIScan"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kjaylee/TensorFlowLiteSwift.git", from: "2.17.1")
    ],
    targets: [
        // 실제 바이너리 프레임워크
        .binaryTarget(
            name: "AIScanBinary",
            path: "AIScan.xcframework"
        ),
        // Wrapper target – 의존성 추가를 위해 필요
        .target(
            name: "AIScan",
            dependencies: [
                "AIScanBinary",
                .product(name: "TensorFlowLiteSwift", package: "TensorFlowLiteSwift")
            ],
            path: "Sources/AIScanStub",
            publicHeadersPath: "."
        )
    ]
)

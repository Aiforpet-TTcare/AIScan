// swift-tools-version: 6.1
// tag: "1.3.8-lite"
import PackageDescription

let package = Package(
    name: "AIScan",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // 외부에 노출되는 라이브러리명은 여전히 "AIScan"
        .library(
            name: "AIScan",
            targets: ["AIScanWrapper"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kjaylee/TensorFlowLiteSwift.git", from: "2.17.4"),
        .package(url: "https://github.com/kjaylee/OnnxRuntimeObjC.git", from: "1.20.1"),
    ],
    targets: [
        // binaryTarget의 이름을 실제 모듈명과 일치시킴
        .binaryTarget(
            name: "AIScan",
            path: "AIScan.xcframework"
        ),
        // Wrapper 타겟: 외부 의존성 결합
        .target(
            name: "AIScanWrapper",
            dependencies: [
                "AIScan",
                .product(name: "TensorFlowLiteSwift", package: "TensorFlowLiteSwift"),
                .product(name: "OnnxRuntimeObjC", package: "OnnxRuntimeObjC"),
            ],
            path: "Sources/AIScanStub",
            publicHeadersPath: "."
        )
    ]
)

// swift-tools-version: 6.1
// tag: "1.0.8"
import PackageDescription

let package = Package(
    name: "aiscan",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "aiscan", // ✅ 그대로
            targets: ["aiscan"] // ⬅️ 소문자로 수정
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kjaylee/TensorFlowLiteSwift.git", branch: "main")
    ],
    targets: [
        .binaryTarget(
            name: "aiscanbinary", // ⬅️ 소문자 권장
            path: "AIScan.xcframework"
        ),
        .target(
            name: "aiscan", // ⬅️ 소문자
            dependencies: [
                "aiscanbinary", // ⬅️ 위와 일치
                .product(name: "TensorFlowLiteSwift", package: "TensorFlowLiteSwift")
            ],
            path: "Sources/AIScanStub",
            publicHeadersPath: "."
        )
    ]
)

// swift-tools-version: 5.9
// Version: "1.0.7"
import PackageDescription

let package = Package(
    name: "aiscan", // 패키지 이름 소문자
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "aiscan", // 외부에서 'import aiskan'으로 사용됨
            targets: ["aiscan"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kjaylee/TensorFlowLiteSwift.git", branch: "main")
    ],
    targets: [
        .binaryTarget(
            name: "aiscanbinary", // 타깃 이름도 일관되게 소문자
            path: "AIScan.xcframework"
        ),
        .target(
            name: "aiscan",
            dependencies: [
                "aiscanbinary",
                .product(name: "TensorFlowLiteSwift", package: "TensorFlowLiteSwift")
            ],
            path: "Sources/aiscanstub" // 폴더도 소문자로 정리 권장
        )
    ]
)
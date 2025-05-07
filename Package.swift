// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AIScan",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "AIScan", targets: ["AIScan"])
    ],
    dependencies: [
        .package(url: "https://github.com/kjaylee/TensorFlowLiteSwift.git", .branch("main"))
    ],
    targets: [
        .binaryTarget(
            name: "AIScan",
            path: "AIScan.xcframework"
        )
    ]
)

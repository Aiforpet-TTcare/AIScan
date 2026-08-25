// swift-tools-version: 5.9
// tag: "3.0.3"
import PackageDescription

let package = Package(
    name: "AIScan",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // 외부 기본 제품은 source UI + Objective-C core 조합만 노출한다.
        .library(
            name: "AIScan",
            targets: ["AIScan"]
        ),
        .library(
            name: "AIScanCore",
            targets: ["AIScanCore"]
        ),
        .library(
            name: "AIScanCameraUI",
            targets: ["AIScanCameraUI"]
        ),
        .library(
            name: "AIScanReferenceUI",
            targets: ["AIScanReferenceUI"]
        )
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "AIScanCore",
            path: "AIScanCore.xcframework"
        ),
        .target(
            name: "AIScan",
            dependencies: ["AIScanCore", "AIScanCameraUI", "AIScanReferenceUI"],
            path: "Sources/AIScan"
        ),
        .target(
            name: "AIScanCameraUI",
            dependencies: ["AIScanCore"],
            path: "Sources/AIScanCameraUI",
            resources: [
                .process("Resources"),
                .process("ReferenceResources")
            ]
        ),
        .target(
            name: "AIScanReferenceUI",
            dependencies: ["AIScanCameraUI"],
            path: "Sources/AIScanReferenceUI"
        ),
        .testTarget(
            name: "AIScanCompatibilityTests",
            dependencies: ["AIScan", "AIScanCameraUI", "AIScanReferenceUI"],
            path: "Tests/AIScanCompatibilityTests"
        )
    ]
)

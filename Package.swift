// swift-tools-version: 5.9
// tag: "2.2.4"
import PackageDescription

let package = Package(
    name: "AIScan",
    platforms: [
        .iOS(.v15)
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
            path: "Sources/AIScanCameraUI"
        ),
        .target(
            name: "AIScanReferenceUI",
            dependencies: ["AIScanCore"],
            path: "Sources/AIScanReferenceUI"
        ),
        .testTarget(
            name: "AIScanCompatibilityTests",
            dependencies: ["AIScan"],
            path: "Tests/AIScanCompatibilityTests"
        )
    ]
)

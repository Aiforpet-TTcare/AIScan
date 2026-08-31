// swift-tools-version: 5.9
// tag: "3.0.9"
import PackageDescription

let package = Package(
    name: "AIScan",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Consumers integrate one facade product and `import AIScan` only.
        .library(
            name: "AIScan",
            targets: ["AIScan"]
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
                .process("PrivacyInfo.xcprivacy"),
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

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "taqlyn_sdk",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "taqlyn-sdk", targets: ["taqlyn_sdk"]),
    ],
    dependencies: [
        // Monorepo sibling: packages/sdk-ios (SPM path ../sdk-ios from packages/sdk-flutter).
        .package(name: "TaqlynSDK", path: "../../../sdk-ios"),
    ],
    targets: [
        .target(
            name: "taqlyn_sdk",
            dependencies: [
                .product(name: "TaqlynSDK", package: "TaqlynSDK"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)

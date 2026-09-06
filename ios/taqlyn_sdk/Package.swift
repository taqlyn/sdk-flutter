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
        .package(url: "https://github.com/taqlyn/sdk-ios.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "taqlyn_sdk",
            dependencies: [
                .product(name: "TaqlynSDK", package: "sdk-ios"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)

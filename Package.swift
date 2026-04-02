// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-dependencies-http-client",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HTTPClient", targets: ["HTTPClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.2"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.3.6"),

        .package(url: "https://github.com/apple/swift-http-types", from: "1.4.0"),
        .package(url: "https://github.com/skiptools/swift-android-native", from: "1.0.0")
    ],
    targets: [

        .target(
            name: "HTTPClient",
            dependencies: [
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),

                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),

                .product(name: "AndroidLogging", package: "swift-android-native")
            ]
        ),

        .testTarget(name: "HTTPClientTests", dependencies: ["HTTPClient"])
    ]
)

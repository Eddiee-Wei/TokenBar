// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TokenBarCore", targets: ["TokenBarCore"]),
        .executable(name: "TokenBarApp", targets: ["TokenBarApp"]),
        .executable(name: "tokenbar", targets: ["TokenBarCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.1")
    ],
    targets: [
        .target(
            name: "TokenBarCore",
            path: "Sources/TokenBarCore"
        ),
        .executableTarget(
            name: "TokenBarApp",
            dependencies: ["TokenBarCore"],
            path: "Sources/TokenBarApp"
        ),
        .executableTarget(
            name: "TokenBarCLI",
            dependencies: ["TokenBarCore"],
            path: "Sources/TokenBarCLI"
        ),
        .testTarget(
            name: "TokenBarCoreTests",
            dependencies: [
                "TokenBarCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/TokenBarCoreTests"
        )
    ]
)

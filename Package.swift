// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftRuntimeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SwiftRuntimeKit", targets: ["SwiftRuntimeKit"]),
        .executable(name: "srk", targets: ["SwiftRuntimeKitCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0")
    ],
    targets: [
        .target(
            name: "SwiftRuntimeKit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/SwiftRuntimeKit"
        ),
        .executableTarget(
            name: "SwiftRuntimeKitCLI",
            dependencies: ["SwiftRuntimeKit"],
            path: "Sources/SwiftRuntimeKitCLI"
        ),
        .testTarget(
            name: "SwiftRuntimeKitTests",
            dependencies: ["SwiftRuntimeKit"],
            path: "Tests/SwiftRuntimeKitTests"
        )
    ]
)

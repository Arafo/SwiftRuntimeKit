// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftRuntimeKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwiftRuntimeKit", targets: ["SwiftRuntimeKit"]),
        .executable(name: "SwiftRuntimeDemo", targets: ["SwiftRuntimeDemo"])
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
            name: "SwiftRuntimeDemo",
            dependencies: ["SwiftRuntimeKit"],
            path: "Sources/SwiftRuntimeDemo"
        )
    ]
)

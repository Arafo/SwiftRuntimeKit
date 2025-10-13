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
        // none
    ],
    targets: [
        .target(
            name: "SwiftRuntimeKit",
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

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalHostManager",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "LocalHostManager",
            targets: ["LocalHostManager"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "LocalHostManager"
        ),
    ]
)

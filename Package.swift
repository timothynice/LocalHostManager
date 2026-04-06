// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Studi0Ports",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "Studi0Ports",
            targets: ["Studi0Ports"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Studi0Ports"
        ),
    ]
)

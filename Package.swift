// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoConverter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VideoConverter",
            dependencies: [],
            path: "Sources/VideoConverter"
        )
    ]
)
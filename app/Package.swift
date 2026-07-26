// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "UsageOwl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "UsageOwl",
            path: "Sources/UsageOwl"
        )
    ]
)

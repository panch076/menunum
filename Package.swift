// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "menunum",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "menunum", path: "Sources/menunum")
    ]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "menunum",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MenuNumKit", targets: ["MenuNumKit"]),
        .executable(name: "menunum", targets: ["menunum"]),
    ],
    targets: [
        .target(name: "MenuNumKit"),
        .executableTarget(name: "menunum", dependencies: ["MenuNumKit"]),
        .executableTarget(name: "menunum-demo", dependencies: ["MenuNumKit"], path: "Examples/Demo"),
        .testTarget(name: "MenuNumKitTests", dependencies: ["MenuNumKit"]),
    ]
)

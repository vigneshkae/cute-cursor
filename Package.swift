// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorStudio",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CursorStudio", targets: ["CursorStudio"])],
    targets: [
        .target(name: "CursorSystem", linkerSettings: [.linkedFramework("ApplicationServices")]),
        .executableTarget(name: "CursorStudio", dependencies: ["CursorSystem"], resources: [.copy("Resources/SoftBloom")]),
        .testTarget(name: "CursorStudioTests", dependencies: ["CursorStudio"])
    ]
)

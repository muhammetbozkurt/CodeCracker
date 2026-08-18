// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodeCrackerKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CodeCrackerKit", targets: ["CodeCrackerKit"]),
        .executable(name: "codecracker", targets: ["CodeCrackerCLI"]),
        .executable(name: "CodeCrackerApp", targets: ["CodeCrackerApp"]),
    ],
    targets: [
        .target(name: "CodeCrackerKit"),
        // A terminal harness for exercising the rules by hand. Not shipped in the app.
        .executableTarget(name: "CodeCrackerCLI", dependencies: ["CodeCrackerKit"]),
        // SwiftUI shell, runnable on the iOS Simulator.
        .executableTarget(name: "CodeCrackerApp", dependencies: ["CodeCrackerKit"]),
        .testTarget(name: "CodeCrackerKitTests", dependencies: ["CodeCrackerKit"]),
    ]
)

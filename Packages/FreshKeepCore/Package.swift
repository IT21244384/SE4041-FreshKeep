// swift-tools-version:5.9
// FreshKeepCore holds every piece of FreshKeep logic that does not depend on
// UIKit/SwiftUI, so it can be shared by the iOS and visionOS apps and unit
// tested on any platform (including CI and Windows/Linux toolchains).
import PackageDescription

let package = Package(
    name: "FreshKeepCore",
    platforms: [.iOS(.v17), .visionOS(.v1), .macOS(.v14)],
    products: [
        .library(name: "FreshKeepCore", targets: ["FreshKeepCore"])
    ],
    targets: [
        .target(name: "FreshKeepCore"),
        .testTarget(name: "FreshKeepCoreTests", dependencies: ["FreshKeepCore"])
    ]
)

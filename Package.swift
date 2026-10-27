// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockPond",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FloatingDock", targets: ["FloatingDock"]),
        .library(name: "GaugeDock", targets: ["GaugeDock"]),
    ],
    targets: [
        .target(name: "FloatingDock"),
        .target(name: "GaugeDock", dependencies: ["FloatingDock"]),
        .testTarget(name: "FloatingDockTests", dependencies: ["FloatingDock"]),
        .testTarget(name: "GaugeDockTests", dependencies: ["GaugeDock"]),
    ]
)

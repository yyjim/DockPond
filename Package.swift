// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "DockPond",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FloatingDock", targets: ["FloatingDock"]),
        .library(name: "GaugeDock", targets: ["GaugeDock"]),
        .library(name: "TweakDock", targets: ["TweakDock"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "700.0.0"),
    ],
    targets: [
        .target(name: "FloatingDock"),
        .target(name: "GaugeDock", dependencies: ["FloatingDock"]),
        .macro(
            name: "TweakDockMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(name: "TweakDock", dependencies: ["TweakDockMacros"]),
        .testTarget(name: "FloatingDockTests", dependencies: ["FloatingDock"]),
        .testTarget(name: "GaugeDockTests", dependencies: ["GaugeDock"]),
        .testTarget(name: "TweakDockTests", dependencies: ["TweakDock"]),
        .testTarget(
            name: "TweakDockMacrosTests",
            dependencies: [
                .target(name: "TweakDockMacros", condition: .when(platforms: [.macOS])),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax", condition: .when(platforms: [.macOS])),
            ]
        ),
    ]
)

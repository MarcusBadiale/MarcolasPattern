// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MarcolasPattern",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(
            name: "MarcolasPattern",
            targets: ["MarcolasPattern"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // The macro implementation (compiler plugin)
        .macro(
            name: "MarcolasPatternMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        // The public library that exposes @MCProvider and @MCView
        .target(
            name: "MarcolasPattern",
            dependencies: ["MarcolasPatternMacros"]
        ),
        // Tests
        .testTarget(
            name: "MarcolasPatternTests",
            dependencies: [
                "MarcolasPatternMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)

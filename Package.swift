// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let settings: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=100"]),
    .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=100"]),
]

let package = Package(
    name: "URLBuilder",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "URLBuilder",
            targets: ["URLBuilder"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0")
    ],
    targets: [
        .target(
            name: "URLBuilder",
            dependencies: ["URLBuilderMacros"],
            swiftSettings: settings,
            plugins: [
                .plugin(name: "PublicSuffixGeneratorPlugin")
            ]
        ),
        .macro(
            name: "URLBuilderMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ],
            swiftSettings: settings
        ),
        .target(
            name: "PublicSuffixGeneratorCore",
            swiftSettings: settings
        ),
        .executableTarget(
            name: "public-suffix-generator",
            dependencies: ["PublicSuffixGeneratorCore"],
            swiftSettings: settings
        ),
        .plugin(
            name: "PublicSuffixGeneratorPlugin",
            capability: .buildTool(),
            dependencies: [
                .target(name: "public-suffix-generator")
            ]
        ),
        .testTarget(
            name: "URLBuilderTests",
            dependencies: ["URLBuilder"],
            swiftSettings: settings
        ),
        .testTarget(
            name: "URLBuilderMacrosTests",
            dependencies: [
                "URLBuilderMacros",
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: settings
        ),
        .testTarget(
            name: "PublicSuffixGeneratorTests",
            dependencies: ["PublicSuffixGeneratorCore"],
            swiftSettings: settings
        ),
    ]
)

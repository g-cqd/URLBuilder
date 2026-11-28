// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

let typeCheckBudgetMS = Context.environment["AD_TYPECHECK_BUDGET_MS"].flatMap { Int($0) } ?? 100
let timingWarningFlags: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-warn-long-function-bodies=\(typeCheckBudgetMS)",
        "-Xfrontend", "-warn-long-expression-type-checking=\(typeCheckBudgetMS)"
    ])
]

let testSettings: [SwiftSetting] =
    strictSettings + timingWarningFlags + [.unsafeFlags(["-enable-actor-data-race-checks"])]

let isDev = Context.environment["URLBUILDER_DEV"] != nil

let aemiJSONDependency: Package.Dependency = .package(
    url: "https://github.com/g-cqd/AemiJSON.git", revision: "4d3fd43b02889f186178801dc599fdb5615bc4ad")

let aemiDependency: Package.Dependency = .package(
    url: "https://github.com/Aemi-Studio/aemi.git", revision: "7aca98cb8cccc833cbfd19f0fee50d29c69df163")

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0"),
    aemiJSONDependency,
    aemiDependency
]
if isDev {
    packageDependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"))
    packageDependencies.append(
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.38.0"))
}

let libraryBuildPlugins: [Target.PluginUsage] =
    isDev
    ? ["PublicSuffixGeneratorPlugin", .plugin(name: "LintBuild", package: "aemi")]
    : ["PublicSuffixGeneratorPlugin"]

let package = Package(
    name: "URLBuilder",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "URLBuilder",
            targets: ["URLBuilder"]
        )
    ],
    dependencies: packageDependencies,
    targets: [
        .target(
            name: "URLBuilder",
            dependencies: [
                "URLBuilderMacros",
                .product(name: "AemiJSON", package: "AemiJSON"),
                .product(name: "AemiKernel", package: "aemi")
            ],
            swiftSettings: strictSettings,
            plugins: libraryBuildPlugins
        ),
        .macro(
            name: "URLBuilderMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "AemiMacroSupport", package: "aemi")
            ],
            swiftSettings: strictSettings
        ),
        .target(
            name: "PublicSuffixGeneratorCore",
            swiftSettings: strictSettings
        ),
        .executableTarget(
            name: "public-suffix-generator",
            dependencies: ["PublicSuffixGeneratorCore"],
            swiftSettings: strictSettings
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
            dependencies: [
                "URLBuilder", "PublicSuffixGeneratorCore",
                .product(name: "AemiTestKit", package: "aemi"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            swiftSettings: testSettings
        ),
        .testTarget(
            name: "URLBuilderMacrosTests",
            dependencies: [
                "URLBuilderMacros",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax")
            ],
            swiftSettings: testSettings
        ),
        .testTarget(
            name: "PublicSuffixGeneratorTests",
            dependencies: ["PublicSuffixGeneratorCore"],
            swiftSettings: testSettings
        )
    ]
)

if isDev {
    package.targets.append(
        .executableTarget(
            name: "URLBuilderSuite",
            dependencies: [
                "URLBuilder",
                .product(name: "Benchmark", package: "benchmark")
            ],
            path: "Benchmarks/URLBuilderSuite",
            swiftSettings: strictSettings,
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ))
}

// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

// Strict, dependency-safe settings applied to every target. `.v6` turns on complete
// strict-concurrency checking; the upcoming features tighten existentials and import
// visibility. None of these are unsafe flags, so the library stays resolvable through a
// version-pinned `.package(url:from:)` requirement.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

// Compile-time type-check timing warnings flag slow expressions / function bodies. They use
// unsafe flags, which would block version-based dependency resolution if applied to any target
// in the shipped `URLBuilder` product, so they live only on the test targets.
let timingWarningFlags: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-warn-long-function-bodies=100",
        "-Xfrontend", "-warn-long-expression-type-checking=100"
    ])
]

// Tests: strict + timing warnings + runtime actor data-race checks.
let testSettings: [SwiftSetting] =
    strictSettings + timingWarningFlags + [.unsafeFlags(["-enable-actor-data-race-checks"])]

// Dev-only tooling is gated behind `URLBUILDER_DEV` so packages that depend on URLBuilder never
// resolve it. Contributors and CI set `URLBUILDER_DEV=1` to enable the DocC plugin
// (`swift package generate-documentation`) and the shared ADBuildTools `format` / `lint` / `LintBuild`
// plugins, which resolve only with the flag set (CI and the git hooks set it).
let isDev = Context.environment["URLBUILDER_DEV"] != nil

// First-party dependencies resolve from a published `main` branch by default, or from a local
// checkout when the matching PATH env var is set — an absolute or relative path of the caller's
// choice, so the checkouts need not be co-located. There is no hardcoded relative default.
//   • `ADJSON_PATH`       → ADJSON (JSON encoding for `Encodable` query values: sorted keys,
//                           unescaped slashes, Foundation-free core)
//   • `ADFOUNDATION_PATH` → ADFoundation (`ADFCore` ASCII / byte primitives)
// (Branch-pinned, so a tagged URLBuilder release cannot itself be resolved via
// `.package(url:from:)` — SwiftPM forbids a versioned package depending on an unversioned one.)
let adjsonDependency: Package.Dependency = {
    if let path = Context.environment["ADJSON_PATH"], !path.isEmpty {
        return .package(path: path)
    }
    return .package(url: "https://github.com/g-cqd/ADJSON.git", branch: "main")
}()

let adfoundationDependency: Package.Dependency = {
    if let path = Context.environment["ADFOUNDATION_PATH"], !path.isEmpty {
        return .package(path: path)
    }
    return .package(url: "https://github.com/g-cqd/ADFoundation.git", branch: "main")
}()

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
    adjsonDependency,
    adfoundationDependency
]
if isDev {
    // Shared lint/format tooling (Format/Lint/LintBuild plugins + canonical `.swift-format`). Dev-only,
    // resolved from a local checkout via `ADBUILDTOOLS_PATH`, otherwise the published `main` branch.
    if let path = Context.environment["ADBUILDTOOLS_PATH"], !path.isEmpty {
        packageDependencies.append(.package(path: path))
    } else {
        packageDependencies.append(
            .package(url: "https://github.com/g-cqd/ADBuildTools.git", branch: "main"))
    }
    packageDependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"))
}

// Build-time formatting enforcement attaches to the library only in dev/CI. A build-tool plugin on
// a library target would otherwise run for everyone who depends on URLBuilder, so it stays gated.
let libraryBuildPlugins: [Target.PluginUsage] =
    isDev
    ? ["PublicSuffixGeneratorPlugin", .plugin(name: "LintBuild", package: "ADBuildTools")]
    : ["PublicSuffixGeneratorPlugin"]

let package = Package(
    name: "URLBuilder",
    // The deployment floor is pinned by ADJSON's `Synchronization` (`Mutex`/`Atomic`) requirement,
    // which ships in macOS 15 / iOS 18 / tvOS 18 / watchOS 11 / visionOS 2. URLBuilder itself only
    // needs macOS 13 / iOS 16 (for `host(percentEncoded:)`), so the ADJSON dependency is what sets
    // the floor here. (The Swift 6.3 tools-version is a *toolchain* requirement, not a deployment one.)
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
                .product(name: "ADJSON", package: "ADJSON"),
                .product(name: "ADFCore", package: "ADFoundation")
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
                .product(name: "ADFMacroSupport", package: "ADFoundation")
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
        // Format / lint / LintBuild come from the shared ADBuildTools dev dependency.
        .testTarget(
            name: "URLBuilderTests",
            dependencies: ["URLBuilder", "PublicSuffixGeneratorCore"],
            swiftSettings: testSettings
        ),
        .testTarget(
            name: "URLBuilderMacrosTests",
            dependencies: [
                "URLBuilderMacros",
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

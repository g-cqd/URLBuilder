// swift-tools-version: 6.4

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
// The budget is env-tunable because `treatAllWarnings(as: .error)` turns an overrun into a HARD
// build error while the measured quantity is type-check WALL TIME — structurally flaky on shared
// CI runners (observed 102–168 ms flips for bodies comfortably under 100 ms locally). CI exports
// AD_TYPECHECK_BUDGET_MS=250 to calibrate for runner noise; unset (local builds) it stays 100 so
// regressions still surface at developer-machine speed.
let typeCheckBudgetMS = Context.environment["AD_TYPECHECK_BUDGET_MS"].flatMap { Int($0) } ?? 100
let timingWarningFlags: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-warn-long-function-bodies=\(typeCheckBudgetMS)",
        "-Xfrontend", "-warn-long-expression-type-checking=\(typeCheckBudgetMS)"
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

// First-party dependencies always resolve from the published `main` branch.
//   • ADJSON       — JSON encoding for `Encodable` query values: sorted keys,
//                    unescaped slashes, Foundation-free core
//   • ADFoundation — `ADFCore` ASCII / byte primitives
// (Branch-pinned, so a tagged URLBuilder release cannot itself be resolved via
// `.package(url:from:)` — SwiftPM forbids a versioned package depending on an unversioned one.)
let adjsonDependency: Package.Dependency = .package(url: "https://github.com/g-cqd/ADJSON.git", branch: "main")

let adfoundationDependency: Package.Dependency = .package(
    url: "https://github.com/Aemi-Studio/aemi.git", branch: "main")

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
    adjsonDependency,
    adfoundationDependency
]
if isDev {
    // Shared lint/format tooling (Format/Lint/LintBuild plugins + canonical `.swift-format`).
    // Dev-only, resolved from the published `main` branch.
    packageDependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"))
    // ordo-one's package-benchmark: the `swift package benchmark` plugin runs the `Benchmarks/`
    // suite with statistical rigor (p-percentile latency, malloc/throughput metrics). Dev-gated so
    // downstream consumers of URLBuilder never resolve it. Matches the sibling packages' setup.
    packageDependencies.append(
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.4.0"))
    // ADTestKit is folded into ADFoundation; the test target references it via `package: "aemi"`
    // (adfoundationDependency is already a non-dev dependency for ADFCore + ADFMacroSupport).
}

// Build-time formatting enforcement attaches to the library only in dev/CI. A build-tool plugin on
// a library target would otherwise run for everyone who depends on URLBuilder, so it stays gated.
let libraryBuildPlugins: [Target.PluginUsage] =
    isDev
    ? ["PublicSuffixGeneratorPlugin", .plugin(name: "LintBuild", package: "aemi")]
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
        // Format / lint / LintBuild come from the shared ADBuildTools dev dependency.
        .testTarget(
            name: "URLBuilderTests",
            dependencies: [
                "URLBuilder", "PublicSuffixGeneratorCore",
                // Unconditional: 8 test files import ADTestKit with no `#if canImport` guard, so
                // gating this behind URLBUILDER_DEV made a plain `swift test` a hard compile failure.
                // ADFoundation is already a non-dev dependency, so this costs consumers nothing.
                .product(name: "AemiTestKit", package: "aemi"),
                // On a clean build SwiftPM links the `URLBuilderMacros` *-testable* object into this
                // bundle too (it is only meant to be a compile-time plugin for the `URLBuilder` library);
                // that object references swift-syntax + the compiler-plugin runtime, so without these
                // products on the link line the bundle fails with undefined symbols. Linking them here is
                // a no-op for the macro's own plugin build and keeps clean (CI) builds green.
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
                // `@testable import URLBuilderMacros` pulls the whole macro object — its `@main`
                // `CompilerPlugin.main()` entry and every SwiftSyntax reference — into the test bundle's
                // link. Those are otherwise only *compile-time* dependencies of the `.macro` target, so on
                // a clean build the symbols are undefined at link. Mirror the macro target's swift-syntax
                // product set here so the test bundle links them all (a no-op for the plugin's own build).
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
    // ordo-one package-benchmark suite (URLBUILDER_DEV-gated): `URLBUILDER_DEV=1 swift package benchmark`
    // runs the `Benchmarks/URLBuilderSuite` percentile suite (URL-assembly DSL, query/percent-encoding,
    // public-suffix lookup). Lives under `Benchmarks/` per the framework's convention, matching siblings.
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

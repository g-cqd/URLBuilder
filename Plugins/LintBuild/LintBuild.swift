import Foundation
import PackagePlugin

/// Enforces formatting during the build as a prebuild step.
///
/// Runs `swift format lint --strict` over a target's Swift sources, so a non-zero exit fails the
/// build. Attached to `URLBuilder` only when `URLBUILDER_DEV` is set (see Package.swift), so it
/// never runs for packages that merely depend on URLBuilder.
@main
struct LintBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let module = target.sourceModule else { return [] }
        let swiftFiles = module.sourceFiles(withSuffix: "swift").map(\.url.path)
        guard !swiftFiles.isEmpty else { return [] }

        let swift = try context.tool(named: "swift")
        return [
            .prebuildCommand(
                displayName: "swift format lint (\(target.name))",
                executable: swift.url,
                arguments: ["format", "lint", "--strict"] + swiftFiles,
                outputFilesDirectory: context.pluginWorkDirectoryURL)
        ]
    }
}

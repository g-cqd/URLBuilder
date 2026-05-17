import Foundation
import PackagePlugin

/// Build-tool plugin that regenerates `PublicSuffix.swift` from the.
///
/// vendored IANA Root Zone Database and Mozilla Public Suffix List
/// before `URLBuilder` compiles. The command's inputs and outputs are
/// declared so SwiftPM only re-runs it when the upstream files change.
@main
struct PublicSuffixGeneratorPlugin: BuildToolPlugin {
    private enum PluginError: Error, CustomStringConvertible {
        case missingInput(String)

        var description: String {
            switch self {
                case .missingInput(let path):
                    "PublicSuffixGeneratorPlugin missing required input: \(path)"
            }
        }
    }

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let tool = try context.tool(named: "public-suffix-generator")
        let resources = context.package.directoryURL
            .appending(path: "Documentation/References/TLDs", directoryHint: .isDirectory)
        let ianaFile = resources.appending(path: "tlds-alpha-by-domain.txt")
        let pslFile = resources.appending(path: "public_suffix_list.dat")
        let outputFile = context.pluginWorkDirectoryURL.appending(path: "PublicSuffix.swift")

        try requireInput(ianaFile)
        try requireInput(pslFile)

        return [
            .buildCommand(
                displayName: "Generate PublicSuffix.swift for \(target.name)",
                executable: tool.url,
                arguments: [
                    ianaFile.path(percentEncoded: false),
                    pslFile.path(percentEncoded: false),
                    outputFile.path(percentEncoded: false),
                ],
                inputFiles: [ianaFile, pslFile],
                outputFiles: [outputFile]
            )
        ]
    }

    private func requireInput(_ url: URL) throws {
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else {
            throw PluginError.missingInput(path)
        }
    }
}

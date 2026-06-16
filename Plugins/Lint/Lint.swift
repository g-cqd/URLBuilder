import Foundation
import PackagePlugin

/// Checks formatting and shipped-library discipline (`swift package lint`).
///
/// The single source of truth for the project's lint rules:
///   1. a formatting gate via `swift format lint --strict`, and
///   2. shipped-library discipline in the shipped library target `Sources/URLBuilder`:
///      - no force-unwrap / force-try / force-cast, and
///      - no planning artifacts (`TODO`/`FIXME`/`Phase N`/`[Pn]`) or stray `print(`.
///      Tests, macros, and the generator are exempt. A single reviewed exception can be annotated
///      with a trailing `// lint:allow` comment.
@main
struct LintPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let root = context.package.directoryURL
        var failed = false

        // 1. Formatting gate across the package.
        let paths = ["Sources", "Tests", "Plugins", "Package.swift"].map { root.appending(path: $0).path }
        let swift = try context.tool(named: "swift")
        let format = Process()
        format.executableURL = swift.url
        format.arguments = ["format", "lint", "--strict", "--recursive"] + paths
        try format.run()
        format.waitUntilExit()
        if format.terminationStatus != 0 { failed = true }

        // 2. Shipped-library discipline across the shipped library target.
        let bannedUnwraps = try Regex(#"(\btry!|\bas!|baseAddress!|\.first!)"#)
        // Planning artifacts and debug prints must never ship in the library target.
        let bannedArtifacts = try Regex(#"(\bTODO\b|\bFIXME\b|\bPhase [0-9]|\[P[0-9]\]|\bprint\s*\()"#)
        for target in ["Sources/URLBuilder"] {
            let lib = root.appending(path: target)
            guard let walker = FileManager.default.enumerator(at: lib, includingPropertiesForKeys: nil) else {
                continue
            }
            while let file = walker.nextObject() as? URL {
                guard file.pathExtension == "swift",
                    let text = try? String(contentsOf: file, encoding: .utf8)
                else { continue }
                for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    // A reviewed exception opts out with a trailing `// lint:allow` marker.
                    guard !line.contains("lint:allow") else { continue }
                    if line.contains(bannedUnwraps) {
                        Diagnostics.error(
                            "\(file.lastPathComponent):\(offset + 1): force unwrap / force try / force cast is "
                                + "banned in shipped library code (annotate a reviewed case with // lint:allow)")
                        failed = true
                    }
                    if line.contains(bannedArtifacts) {
                        Diagnostics.error(
                            "\(file.lastPathComponent):\(offset + 1): planning artifact "
                                + "(TODO/FIXME/Phase N/[Pn]) or stray print( is banned in shipped library code "
                                + "(annotate a reviewed case with // lint:allow)")
                        failed = true
                    }
                }
            }
        }

        if failed {
            Diagnostics.error("lint failed")
        } else {
            print("lint clean")
        }
    }
}

import Foundation
import PublicSuffixGeneratorCore

@main
enum Tool {
    private enum ExitCode {
        static let usage: Int32 = 64
        static let dataError: Int32 = 65
    }

    private enum GeneratorCLIError: Error, CustomStringConvertible {
        case missingInput(String)

        var description: String {
            switch self {
                case .missingInput(let path):
                    "public-suffix-generator: input file does not exist: \(path)"
            }
        }
    }

    static func main() {
        do {
            try run()
        } catch let error as GeneratorCLIError {
            printError(error.description)
            exit(ExitCode.dataError)
        } catch {
            printError("public-suffix-generator: \(error)")
            exit(ExitCode.dataError)
        }
    }

    private static func run() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else {
            let usage =
                "usage: public-suffix-generator <iana-tld-list> <psl-file> <output-swift-file>\n"
            try FileHandle.standardError.write(contentsOf: Data(usage.utf8))
            exit(ExitCode.usage)
        }

        guard FileManager.default.fileExists(atPath: arguments[1]) else {
            throw GeneratorCLIError.missingInput(arguments[1])
        }
        guard FileManager.default.fileExists(atPath: arguments[2]) else {
            throw GeneratorCLIError.missingInput(arguments[2])
        }

        let ianaURL = URL(filePath: arguments[1], directoryHint: .notDirectory)
        let pslURL = URL(filePath: arguments[2], directoryHint: .notDirectory)
        let outputURL = URL(filePath: arguments[3], directoryHint: .notDirectory)

        let ianaSource = try String(contentsOf: ianaURL, encoding: .utf8)
        let pslSource = try String(contentsOf: pslURL, encoding: .utf8)

        let generated = PublicSuffixGenerator.generate(
            ianaSource: ianaSource,
            pslSource: pslSource
        )

        let outputDirectory = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        try generated.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    private static func printError(_ message: String) {
        try? FileHandle.standardError.write(contentsOf: Data((message + "\n").utf8))
    }
}

import Foundation
import Testing

@Suite("Documentation — standards appendix coverage")
struct DocumentationCoverageTests {

    @Test
    func `Appendix-cited test names exist in the test suite`() throws {
        let root = URL(
            filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
        let appendixURL = root.appending(path: "Documentation/Appendix-StandardsCoverage.md")
        let testsURL = root.appending(path: "Tests", directoryHint: .isDirectory)

        let appendix = try String(contentsOf: appendixURL, encoding: .utf8)
        let testNames = try swiftTestNames(at: testsURL)
        let citedNames = try citedTestNames(in: appendix)
        let missingNames = citedNames.filter { testNames.contains($0) == false }

        #expect(
            missingNames.isEmpty,
            "Appendix cites test names that do not appear in Tests/: \(missingNames.sorted().joined(separator: ", "))"
        )
    }

    private func swiftTestNames(at root: URL) throws -> Set<String> {
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            )
        else {
            return []
        }

        let testNameRegex = try NSRegularExpression(
            pattern: #"func\s+(?:`([^`]+)`|([A-Za-z_][A-Za-z0-9_]*))\s*\("#
        )

        var names: Set<String> = []
        for item in enumerator {
            guard let fileURL = item as? URL, fileURL.pathExtension == "swift" else {
                continue
            }
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in testNameRegex.matches(in: source, range: range) {
                let capturedRange =
                    match.range(at: 1).location == NSNotFound
                    ? match.range(at: 2)
                    : match.range(at: 1)
                guard let nameRange = Range(capturedRange, in: source) else {
                    continue
                }
                names.insert(String(source[nameRange]))
            }
        }
        return names
    }

    private func citedTestNames(in markdown: String) throws -> Set<String> {
        let codeSpanRegex = try NSRegularExpression(pattern: #"`([^`]+)`"#)

        var names: Set<String> = []
        var testColumnIndex: Int?

        for line in markdown.split(separator: "\n") {
            let cells = markdownTableCells(in: String(line))
            guard cells.isEmpty == false else {
                continue
            }

            if let index = cells.firstIndex(of: "Test") {
                testColumnIndex = index
                continue
            }

            guard let testColumnIndex,
                testColumnIndex < cells.count,
                isMarkdownTableDivider(cells) == false
            else {
                continue
            }

            let testCell = cells[testColumnIndex]
            for token in codeSpans(in: testCell, regex: codeSpanRegex) {
                guard let name = testName(from: token) else {
                    continue
                }
                names.insert(name)
            }
        }

        return names
    }

    private func codeSpans(in text: String, regex: NSRegularExpression) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let tokenRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[tokenRange])
        }
    }

    private func markdownTableCells(in line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|") else {
            return []
        }

        return
            trimmed
            .dropFirst()
            .dropLast()
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func isMarkdownTableDivider(_ cells: [String]) -> Bool {
        cells.allSatisfy { cell in
            cell.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private func testName(from token: String) -> String? {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.hasPrefix("Documentation/") == false,
            token.hasPrefix("References/") == false,
            token.hasPrefix("RFCs/") == false,
            token.hasPrefix("ISO-IEC/") == false,
            token.hasPrefix("Tests/") == false
        else {
            return nil
        }

        let rawName: Substring
        if token.contains("/") {
            guard
                let splitName =
                    token
                    .split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
                    .last
            else {
                return nil
            }
            rawName = splitName
        } else {
            rawName = token[...]
        }
        let name =
            rawName
            .trimmingPrefix { $0 == "…" }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : String(name)
    }
}

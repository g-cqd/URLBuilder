import Testing

@testable import PublicSuffixGeneratorCore

// MARK: - Fixtures

private let ianaFixture = """
    # Version 2099010100, Last Updated Mon Jan  1 00:00:00 2099 UTC
    COM
    NET
    ORG
    CO
    TEST
    12345
    XN--FIQS8S
    """

private let pslFixture = """
    // ===BEGIN ICANN DOMAINS===
    // Some comment
    com
    net
    org

    // gTLD-style example
    co.uk
    *.aichi.nagoya
    !city.nagoya
    example.test
    xn--fiqs8s
    삼성
    // ===END ICANN DOMAINS===
    // ===BEGIN PRIVATE DOMAINS===
    some.private.suffix
    // ===END PRIVATE DOMAINS===
    """

private let pslWithHeaders = """
    // VERSION: 2026-05-01_02-51-25_UTC
    // COMMIT: 8b4345f9a2513011b21e6fc7b8a7197a849be52c
    // ===BEGIN ICANN DOMAINS===
    com
    co.uk
    // ===END ICANN DOMAINS===
    """

// MARK: - IANA parsing

@Suite("IANA parser")
struct IANAParserTests {
    @Test
    func `captures the version line and strips the leading hash`() {
        let catalogue = PublicSuffixGenerator.parseIANA(ianaFixture)
        #expect(
            catalogue.version == "Version 2099010100, Last Updated Mon Jan  1 00:00:00 2099 UTC")
    }

    @Test
    func `lowercases every TLD label`() {
        let catalogue = PublicSuffixGenerator.parseIANA(ianaFixture)
        #expect(catalogue.tlds.allSatisfy { $0 == $0.lowercased() })
    }

    @Test
    func `preserves Punycode labels untouched after lowercasing`() {
        let catalogue = PublicSuffixGenerator.parseIANA(ianaFixture)
        #expect(catalogue.tlds.contains("xn--fiqs8s"))
    }

    @Test
    func `produces a deduplicated, byte-sorted list`() {
        let withDuplicates = """
            # Version test
            COM
            com
            NET
            """
        let catalogue = PublicSuffixGenerator.parseIANA(withDuplicates)
        #expect(catalogue.tlds == ["com", "net"])
    }

    @Test
    func `ignores multi-token lines (defensive against stray tokens)`() {
        let source = """
            # Version test
            com
            not a tld
            net
            """
        let catalogue = PublicSuffixGenerator.parseIANA(source)
        #expect(catalogue.tlds == ["com", "net"])
    }

    @Test
    func `rejects non-LDH tokens before source emission`() {
        let source = """
            # Version test
            com
            bad"label
            bad\\label
            net
            """
        let catalogue = PublicSuffixGenerator.parseIANA(source)
        #expect(catalogue.tlds == ["com", "net"])
    }
}

// MARK: - PSL parsing

@Suite("PSL parser")
struct PSLParserTests {
    @Test
    func `captures VERSION and COMMIT headers when present`() {
        let catalogue = PublicSuffixGenerator.parsePSL(pslWithHeaders)
        #expect(catalogue.version == "2026-05-01_02-51-25_UTC")
        #expect(catalogue.commit == "8b4345f9a2513011b21e6fc7b8a7197a849be52c")
    }

    @Test
    func `only ingests lines inside the ICANN section`() {
        let catalogue = PublicSuffixGenerator.parsePSL(pslFixture)
        #expect(!catalogue.suffixes.contains("some.private.suffix"))
    }

    @Test
    func `tracks wildcard parent rules separately`() {
        let catalogue = PublicSuffixGenerator.parsePSL(pslFixture)
        #expect(catalogue.wildcardParents.contains("aichi.nagoya"))
        #expect(!catalogue.suffixes.contains("aichi.nagoya"))
        #expect(!catalogue.suffixes.contains(where: { $0.hasPrefix("*.") }))
    }

    @Test
    func `tracks exception rules separately`() {
        let catalogue = PublicSuffixGenerator.parsePSL(pslFixture)
        #expect(catalogue.exceptions.contains("city.nagoya"))
        #expect(!catalogue.suffixes.contains("city.nagoya"))
        #expect(!catalogue.suffixes.contains(where: { $0.hasPrefix("!") }))
    }

    @Test
    func `canonicalizes non-ASCII suffixes to A-label form`() {
        let catalogue = PublicSuffixGenerator.parsePSL(pslFixture)
        #expect(catalogue.suffixes.contains("xn--cg4bki"))
    }

    @Test
    func `sorts suffixes in raw UTF-8 byte order`() {
        let catalogue = PublicSuffixGenerator.parsePSL(pslFixture)
        let expected = catalogue.suffixes.sorted { lhs, rhs in
            lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
        }
        #expect(catalogue.suffixes == expected)
    }

    @Test
    func `rejects source-injection tokens before emission`() {
        let source = """
            // ===BEGIN ICANN DOMAINS===
            com
            legit.com"
            evil\\label.com
            ok.test
            // ===END ICANN DOMAINS===
            """
        let catalogue = PublicSuffixGenerator.parsePSL(source)
        #expect(catalogue.suffixes == ["com", "ok.test"])
    }
}

// MARK: - Identifier rules

@Suite("Swift identifier rules")
struct IdentifierTests {
    @Test
    func `hyphens are converted to underscores`() {
        #expect(PublicSuffixGenerator.swiftIdentifier(for: "co-op") == "co_op")
    }

    @Test
    func `a leading digit is prefixed with an underscore`() {
        #expect(PublicSuffixGenerator.swiftIdentifier(for: "12345") == "_12345")
    }

    @Test
    func `Swift keywords are backtick-escaped`() {
        #expect(PublicSuffixGenerator.swiftIdentifier(for: "in") == "`in`")
        #expect(PublicSuffixGenerator.swiftIdentifier(for: "is") == "`is`")
    }

    @Test
    func `ordinary labels pass through unchanged`() {
        #expect(PublicSuffixGenerator.swiftIdentifier(for: "com") == "com")
    }
}

// MARK: - Emission

@Suite("Emission")
struct EmissionTests {
    @Test
    func `output is deterministic for the same input`() {
        let first = PublicSuffixGenerator.generate(ianaSource: ianaFixture, pslSource: pslFixture)
        let second = PublicSuffixGenerator.generate(ianaSource: ianaFixture, pslSource: pslFixture)
        #expect(first == second)
    }

    @Test
    func `output declares one TopLevelDomain constant per IANA TLD`() {
        let output = PublicSuffixGenerator.generate(ianaSource: ianaFixture, pslSource: pslFixture)
        #expect(output.contains("public static let com = TopLevelDomain(\"com\")"))
        #expect(output.contains("public static let _12345 = TopLevelDomain(\"12345\")"))
        #expect(
            output.contains("public static let `in`")
                == false)  // "in" is not in the IANA fixture; sanity check
    }

    @Test
    func `output exposes icannTLDs and icannSuffixes sets`() {
        let output = PublicSuffixGenerator.generate(ianaSource: ianaFixture, pslSource: pslFixture)
        #expect(output.contains("public static let icannTLDs: Set<String>"))
        #expect(output.contains("public static let icannSuffixes: Set<String>"))
        #expect(output.contains("public static let icannWildcardParents: Set<String>"))
        #expect(output.contains("public static let icannExceptions: Set<String>"))
    }

    @Test
    func `output exposes contains(_:) and longestMatch(for:)`() {
        let output = PublicSuffixGenerator.generate(ianaSource: ianaFixture, pslSource: pslFixture)
        #expect(output.contains("public static func contains(_ suffix: String)"))
        #expect(output.contains("public static func longestMatch(for host: String)"))
    }

    @Test
    func `counts in the file header reflect the parsed input`() {
        let output = PublicSuffixGenerator.generate(ianaSource: ianaFixture, pslSource: pslFixture)
        let iana = PublicSuffixGenerator.parseIANA(ianaFixture)
        let psl = PublicSuffixGenerator.parsePSL(pslFixture)
        #expect(output.contains("IANA single-label TLDs    = \(iana.tlds.count)"))
        #expect(output.contains("PSL ICANN literal suffixes = \(psl.suffixes.count)"))
        #expect(output.contains("PSL ICANN wildcard rules   = \(psl.wildcardParents.count)"))
        #expect(output.contains("PSL ICANN exceptions       = \(psl.exceptions.count)"))
    }

    @Test
    func `escapes emitted Swift string literals defensively`() {
        let iana = PublicSuffixGenerator.IANACatalogue(version: "test", tlds: ["com"])
        let psl = PublicSuffixGenerator.PSLCatalogue(
            version: "test",
            commit: "test",
            suffixes: ["bad\"suffix"],
            wildcardParents: ["bad\\wildcard"],
            exceptions: []
        )
        let output = PublicSuffixGenerator.emit(iana: iana, psl: psl)
        #expect(output.contains(#""bad\"suffix","#))
        #expect(output.contains(#""bad\\wildcard","#))
    }
}

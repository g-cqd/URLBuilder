# URLBuilder

A Swift 6 result-builder DSL for constructing validated URLs. Every component is type-checked, validations follow RFC 3986 / WHATWG URL / IDNA rules, and URLs are built via Foundation `URLComponents` rather than string concatenation.

```swift
import URLBuilder

let url: URL = URLBuilder {
    HTTPS {
        Subdomain("www")
        Domain("apple")
        TLD.com
        Path("search")
        Query("q", "swift")
    }
}
// https://www.apple.com/search?q=swift
```

For dynamic or untrusted inputs, use the throwing entry point:

```swift
let url = try URLBuilder.build {
    HTTPS {
        Domain(userHost)
        Path(userPath)
    }
}
```

## Requirements

- Swift 6.4+ (Swift 6 language mode, strict concurrency)
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, visionOS 2+, or Linux

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/g-cqd/URLBuilder.git", branch: "main")
]
```

## Capabilities

- **Scheme & authority builders:** `HTTP`, `HTTPS`, custom schemes, IPv4/IPv6/IDNA hosts, domains, subdomains, ports, and curated IANA TLDs / Public Suffix List data.
- **Safe encoding & validation:** component-specific percent-encoding, strict error reporting (`URLBuilderError`), and security checks against smuggling, credential leakage, and invalid hosts.
- **DocC documentation:** full API guides in `Sources/URLBuilder/URLBuilder.docc/`.

## Documentation

- [Standards](docs/Standards.md)
- [Requirements](docs/Requirements.md)
- [Standards Coverage](docs/Appendix-StandardsCoverage.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## License

[MIT](LICENSE)

# URLBuilder

A Swift 6 result-builder DSL for declaring URLs with a SwiftUI-style shape.
Every component is type-checked, every validation traces back to a specific
RFC clause, and every URL is produced through Foundation `URLComponents`
rather than string concatenation.

```swift
import URLBuilder

let url: URL = URLBuilder {
    HTTPS {
        Subdomain("www")
        Domain("apple")
        TLD.com
        Query("search", "some value")
    }
}

// https://www.apple.com?search=some%20value
```

## Entry points

The runtime builders expose two contracts:

`URLBuilder { … } -> URL` is for static, SwiftUI-style declarations. It
traps on invalid input — the assumption is that an invalid URL at this
site is a programmer error and should fail fast.

`withThrowingURL { … } throws(URLBuildError) -> URL` is for
declarations that include runtime input. Failures surface through Swift
typed throws as a closed `URLBuildError` enum, so every caller has to
consider every possible rejection.

```swift
let url = try withThrowingURL {
    HTTPS {
        Host("api.apple.com")
        Path("v1", "tickets")
        Query("status", "open")
        Query("preview")
    }
}
```

The freestanding `#URL { … }` macro forwards to `URLBuilder`; it exists
for expression contexts such as property getters and accepts the same
optional configuration argument.

```swift
var endpoint: URL {
    #URL(configuration: .strict) {
        HTTPS("apple", TLD.com)
    }
}
```

## Compact, typed declarations

Capitalized component declarations (`Host`, `Path`, `Query`,
`Fragment`, `TLD`, …) keep URL pieces distinct without string-packing:

```swift
let url = try withThrowingURL {
    HTTPS {
        Host {
            .subdomain("www")
                .domain("apple")
                .tld(.com)
        }
        Path("tickets", "123")
        Query("search", "some value")
        Fragment("results")
    }
}
```

For the most compact typed shape, host and path each take their own
builder, while query items are listed as individual `Query`
declarations. A string in `Host` is one DNS label; `TLD.com` is a typed
top-level domain; a string in `Path` is one path segment:

```swift
let url = try withThrowingURL {
    HTTPS {
        Host {
            "www"
            "apple"
            TLD.com
        }
        Path {
            "tickets"
            "123"
        }
        Query("search", "some value")
        Query("preview")
        Query("page", 2)
        Query("filter", SearchFilter(page: 2, status: "open"))
        Fragment("results")
    }
}
```

We keep complete-host string overloads as an escape hatch for hosts
that already arrive as a single string from external input:

```swift
let url = try withThrowingURL {
    HTTPS("www.apple.com") {
        Path("tickets", "123")
    }
}
```

## Top-level domains and public suffixes

Every currently delegated single-label TLD is exposed as a `static let`
on `TopLevelDomain`. `tld(...)` is a shorthand for `topLevelDomain(...)`
and is available everywhere the long form is.

```swift
HTTPS("apple", TLD.com)        // .com, .org, .net, .io, .dev, ...
```

Multi-label suffixes (`co.uk`, `com.au`, `aichi.nagoya`, …) are reached
by chaining labels onto a TLD. The first hop is a real constant;
subsequent hops compose at the call site:

```swift
HTTPS("bbc", TLD.co.uk)           // co.uk
HTTPS("abc", TLD.com.au)          // com.au
HTTPS("nagoya", TLD.aichi.nagoya) // aichi.nagoya
```

The full ICANN public-suffix catalogue is reachable through
`PublicSuffix`:

```swift
PublicSuffix.icannTLDs.contains("com")            // true
PublicSuffix.icannSuffixes.contains("co.uk")      // true
PublicSuffix.icannWildcardParents.contains("kobe.jp") // true
PublicSuffix.longestMatch(for: "example.co.uk")   // "co.uk"
PublicSuffix.contains("home.arpa")                // true (RFC 8375)
```

By default we never reject an unknown suffix. Corporate and home
networks routinely expose custom names (`.corp`, `.lan`, …) that a
strict policy would break, so the catalogue is informational unless
the caller opts in:

```swift
let url = try withThrowingURL(configuration: .strict) {
    HTTPS("example", TLD.com) // OK: com is a known ICANN suffix
}

try withThrowingURL(configuration: .strict) {
    HTTPS("example", TopLevelDomain.custom("foo.bar"))
    // throws .unknownTopLevelDomain("foo.bar")
}
```

In strict mode we check that every composed `tld(...)` value is a known
ICANN suffix and that every host string ends with a longest-matching
ICANN suffix. IPv4 and IPv6 literals are exempt.

The catalogue is generated automatically before every build by the
`PublicSuffixGeneratorPlugin` build tool plugin, sourced from the
vendored IANA Root Zone Database and Mozilla Public Suffix List under
`docs/References/TLDs/`. To pick up upstream changes,
refresh those two files and rebuild — the plugin re-runs whenever its
inputs change.

## Query values

A query value renders one of two ways. Any type conforming to
`URLQueryValueConvertible` renders directly as a plain value — `String`,
`Substring`, `Bool`, the integer and floating-point types, `Decimal` (via
its base-10 `description`), `UUID`, and `Date`, plus `RawRepresentable`
enums over a convertible raw value. Any other `Encodable` value renders as
compact JSON (sorted keys, slashes unescaped) via
[ADJSON](https://github.com/g-cqd/ADJSON), which `URLComponents` then
percent-encodes:

```swift
struct SearchFilter: Encodable, Sendable {
    let page: Int
    let status: String
}

try withThrowingURL {
    HTTPS("api.apple.com") {
        Query("page", 2)                                       // ?page=2
        Query("filter", SearchFilter(page: 2, status: "open")) // JSON-shaped
    }
}
```

For endpoint DTOs, `URLQueryRepresentable` can be written by hand or
synthesized with the `@URLQuery` macro. `@Query` customizes individual
stored properties:

```swift
@URLQuery
struct SearchInput {
    let q: String
    @Query(.key("page_number")) let page: Int?
    let tags: [String]
    @Query(.flag) let strict: Bool
}

let url = try withThrowingURL {
    HTTPS("api.apple.com") {
        SearchInput(q: "swift", page: 2, tags: ["ios"], strict: true)
    }
}
```

Optional properties are omitted when `nil`; arrays and sets unfold to
repeated keys. `Set` iteration is emitted in a deterministic (sorted)
order, so the rendered URL is stable across runs (important for HMAC URL
signing, cache keys, and snapshot tests).

Repeated query keys are preserved by default. Callers that need
map-like behaviour can opt into `URLBuildConfiguration.QueryDeduplication`
with `.firstWins` or `.lastWins`; both policies keep the first
occurrence's position and only choose which value survives.

## Userinfo is opt-in

Userinfo is disabled by default because RFC 3986 deprecates
`user:password` and RFC 9110 deprecates userinfo for `http(s)` URIs.
When a legacy integration or non-HTTP scheme requires it, opt in per
build and pass raw username/password fields through the DSL helpers:

```swift
let configuration = URLBuildConfiguration(userInfoPolicy: .usernameAndPassword)

let url = try withThrowingURL(configuration: configuration) {
    HTTPS("example.com") {
        UserInfo(username: "alice", password: "secret")
    }
}

// https://alice:secret@example.com
```

Userinfo fields are percent-encoded before rendering, so delimiter
characters in raw values cannot change the authority structure. Empty
usernames, forbidden IRI scalars, duplicate userinfo declarations, and
userinfo without a host are rejected.

## What the DSL models

- `scheme ":" hier-part [ "?" query ] [ "#" fragment ]` (RFC 3986 §3)
- Authority-based hosts for `http` and `https` (RFC 9110 §4.2)
- DNS-style composed hosts via typed declarations
  `Host { .subdomain("www").domain("apple").tld(.com) }`
- Full hosts via `Host`, IPv6 literals via `IPv6`, IPvFuture literals
  via `IPLiteral` / `IPvFuture` (RFC 3986 §3.2.2)
- Canonical IPv6 representation per RFC 5952 §4.1–§4.3
- Internationalised domain labels with RFC 5892 §2.4 codepoint
  classification enforced before Foundation IDNA runs, so disallowed
  scalars are rejected rather than silently Punycode-encoded
- Ordered and repeated query items
- Explicit, disabled-by-default userinfo declarations
- Flag queries (`?preview`) kept distinct from empty values (`?preview=`)
- Typed query values through `URLQueryValueConvertible`, `Encodable`,
  `URLQueryRepresentable`, and `@URLQuery`
- Path segments with literal *and* percent-encoded dot-segment rejection
  (RFC 3986 §5.2.4 + RFC 6943 §3.4)

## What the DSL refuses, by construction

Because every rejection happens at build time, callers never have to
chase the same class of bug downstream:

| Rejection | Spec |
|---|---|
| Userinfo unless `URLBuildConfiguration.userInfoPolicy` opts in | RFC 3986 §3.2.1, RFC 9110 §4.2.4 |
| `@` in composed-host labels | RFC 3986 §3.2.1 (no userinfo back-door) |
| C0 controls (CR/LF/NUL/...) in path/query/fragment | RFC 9110 §11.7.6 |
| Literal and percent-encoded `.` / `..` segments | RFC 3986 §5.2.4 + RFC 6943 §3.4 |
| `\` in path segments | RFC 3986 §3.3 (pchar excludes `\`) |
| Port 0 | RFC 6335 §6 |
| IPv6 zone identifiers in URI host literals | RFC 9844 §4 |
| Emoji / symbol / punctuation codepoints in host labels | RFC 5892 §2.4 |

## Standards

We target RFC 3986 (STD 66), RFC 3987, the IDNA2008 stack
(RFC 5890–5894 with codepoint classification per RFC 5892),
the DNS preferred-syntax (RFC 1035 / RFC 1123), Punycode
(RFC 3492), IPv6 canonical form (RFC 4291 + RFC 5952),
`http`/`https` URI behaviour (RFC 9110), zone-ID rules
(RFC 9844), port assignment (RFC 6335), URI scheme
registration (RFC 7595), and the special-use registries
(RFC 2606 / 6761 / 6762 / 7686 / 8375 / 9476). The Mozilla
Public Suffix List and the IANA Root Zone Database supply the
public-suffix catalogue. We treat the WHATWG URL Standard as a
divergence baseline, not a target — its lenient behaviour belongs
to browser parsers, not to a DSL whose job is to refuse malformed
input.

## Documentation

- [`docs/Requirements.md`](docs/Requirements.md) —
  the current requirements and design decisions for the package.
- [`docs/Standards.md`](docs/Standards.md) —
  the standards rationale behind each public API decision.
- [`docs/Appendix-StandardsCoverage.md`](docs/Appendix-StandardsCoverage.md)
  — appendix listing the quality guarantees the package delivers, the
  standard that backs each one, and the test that locks it in.
- [`docs/References/`](docs/References/) — local
  copies of every cited RFC, the Unicode UCD, the IANA Root Zone TLD
  list, the Mozilla Public Suffix List, and the WHATWG URL Standard.

## Testing

Tests are organised by RFC clause under
`Tests/URLBuilderTests/RFCCompliance/`; backtick test names and nearby
test context carry the exact clauses they exercise.

```sh
swift test
```

## Formatting

The repository includes `.swift-format`, based on Swift 6.3
`swift-format` defaults and amended for 4-space indentation, 4-space tab
width, indented switch cases, and the DSL's uppercase entry-point names.
Dependency-free SwiftPM command plugins wrap the toolchain's bundled
`swift-format`, so there is nothing to install:

```sh
swift package format        # format in place
swift package lint          # formatting gate + shipped-library discipline (what CI runs)
```

`swift package lint` is the single source of truth for the lint rules and is
what CI and the committed pre-commit hook run. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for the full developer workflow (git hooks,
sanitizers, the `URLBUILDER_DEV` flag, and the public-suffix generator), and the
[DocC documentation site](https://g-cqd.github.io/URLBuilder/) for the API
reference.

## Requirements

- **Swift 6.3 toolchain or later** (a *toolchain* requirement; the macros and
  strict-concurrency settings need it).
- **Deployment floor: macOS 15 / iOS 18 / tvOS 18 / watchOS 11 / visionOS 2.**
  This is set by the [ADJSON](https://github.com/g-cqd/ADJSON) dependency's use
  of `Synchronization` (`Mutex`/`Atomic`); URLBuilder itself only needs
  macOS 13 / iOS 16 (for `host(percentEncoded:)`).
- A platform with the standard BSD/POSIX IP-address parsing routines
  (`inet_pton`/`inet_ntop`), which we use to canonicalise IPv6 literals and to
  detect IPv4 literals.

## Dependencies

- [**swift-syntax**](https://github.com/swiftlang/swift-syntax) — powers the
  `@URLQuery` / `#URL` macros.
- [**ADJSON**](https://github.com/g-cqd/ADJSON) — the JSON encoding path for
  `Encodable` query values (sorted keys, unescaped slashes, Foundation-free
  core).

swift-docc-plugin is gated behind `URLBUILDER_DEV`, so packages that depend on
URLBuilder never resolve it.

## License

URLBuilder is released under the [MIT License](LICENSE).

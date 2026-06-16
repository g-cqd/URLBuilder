# Getting Started

Add the package, declare your first URL, and choose the entry point that fits.

## Add the package

In `Package.swift`:

```swift
.package(url: "https://github.com/g-cqd/URLBuilder.git", branch: "main")
```

```swift
.target(name: "MyApp", dependencies: ["URLBuilder"])
```

> Note: URLBuilder depends on [ADJSON](https://github.com/g-cqd/ADJSON) for its `Encodable`
> query-value JSON path. While ADJSON is pinned to `main`, a *tagged* URLBuilder release cannot
> be resolved through `.package(url:from:)`; pin a `from:` tag once ADJSON publishes one.

## Two entry points

`URLBuilder { … }` is for static declarations and **traps** on invalid input — ideal for a
literal you control:

```swift
let endpoint: URL = URLBuilder {
    HTTPS {
        Host("api.apple.com")
        Path { "v1"; "tickets" }
    }
}
```

`withThrowingURL { … }` reports validation failures through typed throws, for declarations built
from runtime input:

```swift
let url = try withThrowingURL {
    HTTPS {
        Host(userProvidedHost)
        Path { "v1"; userProvidedID }
        Query("q", searchTerm)
    }
}
```

Every failure is a case of ``URLBuildError`` — a closed enum, so the compiler makes you consider
each rejection.

## Composing the host

Declare a host as a literal, or compose it from typed labels:

```swift
// Literal host
HTTPS { Host("www.apple.com") }

// Composed: subdomain + registrable domain + public suffix
HTTPS {
    Subdomain("www")
    Domain("apple")
    TLD.com
}
```

Multi-label public suffixes use the dynamic-member chain: `TLD.co.uk`, `TLD.com.au`. See
<doc:HostsAndIDNA> and <doc:PublicSuffixes>.

## Adding query items

Pass any scalar (``URLQueryValueConvertible``) or any `Encodable` value:

```swift
HTTPS("example.com") {
    Query("q", "swift")            // q=swift
    Query("page", 2)               // page=2
    Query("filter", SearchFilter(status: "open"))   // filter={"status":"open"}  (compact JSON)
}
```

Or synthesize the whole query block from a DTO with `@URLQuery`:

```swift
@URLQuery
struct Search {
    let q: String
    @Query(.key("page_number")) let page: Int?
    let tags: [String]
    @Query(.flag) let strict: Bool
}
```

See <doc:QueriesAndEncoding>.

## Configuration

Pass a ``URLBuildConfiguration`` to control public-suffix enforcement, query encoding, query
deduplication, and userinfo policy:

```swift
let url = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
    HTTPS("example.com") {
        Query("q", "a")
        Query("q", "b")            // collapses to q=b
    }
}
```

## Requirements

- Swift 6.3+ toolchain (language mode v6).
- macOS 15+ / iOS 18+ / tvOS 18+ / watchOS 11+ / visionOS 2+ (the floor inherited from ADJSON's
  `Synchronization` dependency).

## Next steps

- <doc:HostsAndIDNA> — host validation, IDNA, and IP literals.
- <doc:QueriesAndEncoding> — scalars, `Encodable` JSON, `@URLQuery`, and encoding modes.
- <doc:PublicSuffixes> — strict enforcement and the generated suffix list.
- <doc:Security> — the validation guarantees and threat model.

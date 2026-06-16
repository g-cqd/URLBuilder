# ``URLBuilder``

A Swift 6 result-builder DSL for declaring URLs with a SwiftUI-style shape, where every
component is type-checked and every validation traces back to a specific RFC clause.

## Overview

`URLBuilder` builds URLs by *declaring* their components instead of concatenating strings.
Each component is validated against the standard that governs it (RFC 3986/3987 for syntax,
RFC 5890–5894 for IDNA hosts, the IANA + Mozilla public-suffix lists for registrable domains),
and the final value is produced through Foundation `URLComponents` rather than string
interpolation — so an invalid URL fails at the declaration site, not silently downstream.

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

Two entry points cover the static and dynamic cases:

- `URLBuilder { … } -> URL` is for static, SwiftUI-style declarations; it **traps** on invalid
  input, because an invalid literal URL is a programmer error.
- `withThrowingURL { … } throws(URLBuildError) -> URL` surfaces every rejection through a closed
  ``URLBuildError`` via Swift typed throws, for declarations that include runtime input.

### Why URLBuilder

- **Validated, not concatenated.** Hosts, schemes, path segments, and userinfo are checked
  against an allowlist; traversal (`.`/`..`, percent-encoded dot segments), control characters,
  and bidi overrides are rejected. See <doc:Security>.
- **IDNA-correct hosts.** Unicode hosts are screened for RFC 5892 DISALLOWED scalars before
  Foundation's IDNA pass, closing gaps where Foundation would Punycode a disallowed codepoint.
  See <doc:HostsAndIDNA>.
- **Public-suffix aware.** Opt into strict enforcement to require a registrable domain under a
  known public suffix, matched iteratively against an embedded, build-time-generated list. See
  <doc:PublicSuffixes>.
- **Deterministic queries.** Scalars render through ``URLQueryValueConvertible``; `Encodable`
  values render as compact JSON (sorted keys, unescaped slashes) via the ADJSON engine. See
  <doc:QueriesAndEncoding>.

## Topics

### Essentials

- <doc:GettingStarted>
- ``URLDeclaration``
- ``URLBuildConfiguration``
- ``URLBuildError``

### Guides

- <doc:HostsAndIDNA>
- <doc:QueriesAndEncoding>
- <doc:PublicSuffixes>
- <doc:Security>
- <doc:StandardsCoverage>

### Schemes & authority

- ``Scheme``
- ``HTTP``
- ``HTTPS``
- ``Host``
- ``Subdomain``
- ``Domain``
- ``TopLevelDomain``
- ``UserInfo``
- ``Port``
- ``IPLiteral``
- ``IPvFuture``

### Path, query & fragment

- ``Path``
- ``PathSegment``
- ``Query``
- ``URLQueryValue``
- ``Fragment``

### Query input types

- ``URLQueryRepresentable``
- ``URLQueryValueConvertible``

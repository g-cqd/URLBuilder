# Requirements

This document records URLBuilder's current requirements and the rationale
behind the package design. It is the single starting point for
understanding *why* the public API looks the way it does. The standards
rationale lives in `Standards.md`; the per-feature coverage appendix
lives in `Appendix-StandardsCoverage.md`.

---

## 1. Motivation

Foundation `URL` and `URLComponents` are correct but verbose. Real-world
code regularly stitches URLs together with string interpolation, which:

1. Skips percent-encoding for path/query/fragment.
2. Loses query item order and repeat semantics.
3. Hides invalid input until the URL fails to round-trip much later.
4. Encourages credentials and traversal segments to leak into URLs.

We built URLBuilder to make declaring a URL in Swift as obvious as
declaring a SwiftUI view, while pushing every standards-defined
validation step into the type system or the build step itself.

---

## 2. Goals

- **G1 — Declarative.** A URL is built with a result builder, not by
  string concatenation. The DSL reads top-to-bottom in the order a URL
  is read.
- **G2 — Standards-driven.** Every behaviour traces back to a specific
  IETF RFC clause or ISO/IEC 10646 property. We do not invent ad-hoc
  rules.
- **G3 — Type-safe.** Scheme, host, port, path, query, and fragment
  are distinct at the type level; mixing modes that the URI grammar
  forbids is rejected at compile time.
- **G4 — Explicit construction contracts.**
  `URLBuilder { … } -> URL` for static, SwiftUI-style declarations
  (traps on invalid input).
  `withThrowingURL { … } throws(URLBuildError) -> URL` for runtime input
  (typed-throws).
  `#URL { … }` is macro syntax for the trapping contract.
- **G5 — Predictable validation.** Failures surface as a closed
  `URLBuildError` enum at build time. We never fall back silently.
- **G6 — Credentials are opt-in.** Userinfo is disabled by default,
  and password-style userinfo requires a separate explicit
  configuration choice, in line with the security warnings in RFC
  3986 §3.2.1 and RFC 9110 §4.2.4.

## 2.1 Non-goals

- We do not parse arbitrary URL strings. That is `URLComponents`' job.
- We do not provide HTTP client behaviour. URLBuilder produces `URL`
  values; networking is out of scope.
- We do not target WHATWG URL Standard parity. WHATWG documents
  browser-oriented lenience; we deliberately follow the stricter RFC
  grammar. The deviations we are aware of are pinned by tests in
  `WHATWG_URLDivergence.swift`.

---

## 3. Functional Requirements

### 3.1 Schemes

- **F-Scheme-1.** `https` and `http` are first-class declarations and
  REQUIRE a non-empty host (RFC 9110 §4.2).
- **F-Scheme-2.** Custom schemes are available through
  `URLDeclaration(scheme: Scheme("..."))`. They follow the RFC 3986
  §3.1 / RFC 7595 §3.8 grammar
  `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`.
- **F-Scheme-3.** Scheme is normalised to lowercase per RFC 3986 §6.2.2.1.
- **F-Scheme-4.** Default ports are omitted from the rendered URL: 80
  for `http`, 443 for `https` (RFC 9110 §4.2.3).

### 3.2 Hosts

- **F-Host-1.** Compact typed-host declarations are available:
  `Host { .subdomain("www").domain("example").tld(.com) }`.
  Each piece is a separate DNS label; we do not stuff multiple labels
  into one string.
- **F-Host-2.** A complete host string is also accepted as an escape
  hatch for externally supplied hosts (`HTTPS("www.example.com")`).
- **F-Host-3.** Result builders exist for hosts, paths, and queries:
  `Host { "www"; "example"; TLD.com }`,
  `Path { "tickets"; "123" }`, and `@URLQueryBuilder` bodies.
- **F-Host-4.** Capitalized component declarations (`Host`, `Path`,
  `Query`, `Fragment`, `Domain`, `TLD`) keep simple URLs concise while
  preserving component types.
- **F-Host-5.** IPv6 host literals are first-class via `IPv6` and
  `Host.ipv6`, with optional input bracketing. IPvFuture is available
  via `IPvFuture` / `IPLiteral` for RFC 3986 completeness.
- **F-Host-6.** IPv6 literals are canonicalised to RFC 5952 form
  before they reach the URL.
- **F-Host-7.** A composed host must resolve to a registered domain and
  top-level domain / public suffix. Host-builder strings infer the
  registered domain from the last unclassified label before a `TLD`;
  raw host strings bypass composed-host assembly.

### 3.3 Paths, Queries, Fragments

- **F-Path-1.** Each path segment is a single label. Slash and
  backslash inside a segment are rejected (RFC 3986 §3.3).
- **F-Path-2.** Absent path stays absent. `Path("")` explicitly renders
  as `/` to keep declaration intent visible (RFC 9110 §4.2.3 treats
  empty path and `/` as equivalent).
- **F-Path-3.** Trailing-slash intent is preserved through the
  `PathSegment.trailingSlash` path component.
- **F-Query-1.** Query item order is preserved.
- **F-Query-2.** Repeated names are preserved (`?tag=ios&tag=swift`).
- **F-Query-3.** A query flag (`?preview`, no `=`) is distinct from an
  empty query value (`?preview=`).
- **F-Query-4.** A query value renders through `URLQueryValueConvertible`
  when it conforms (`Bool`/`Int`/`Double`/`Decimal`/`String`/`Substring`/
  `UUID`/`Date`, and `RawRepresentable` over a convertible raw value),
  producing a plain value — `Decimal` uses its base-10 `description`. Any
  other `Encodable` value renders as compact JSON (sorted keys, slashes
  unescaped) via ADJSON.
- **F-Query-5.** Query deduplication is configurable. `.none` is the
  default and preserves repeated keys. `.firstWins` and `.lastWins`
  collapse repeated keys while keeping the first occurrence's rendered
  position.
- **F-Fragment-1.** Fragment grammar follows RFC 3986 §3.5.

### 3.4 TLDs and Public Suffixes

- **F-TLD-1.** Every currently delegated single-label TLD is exposed
  as a constant on `TopLevelDomain`, sourced from the IANA Root Zone
  Database.
- **F-TLD-2.** Multi-label public suffixes are reachable by chaining
  labels onto a TLD (`TLD.co.uk`, `TLD.com.au`, `TLD.aichi.nagoya`).
  The first hop is a real IANA constant; further hops compose at the
  call site.
- **F-TLD-3.** `tld(...)` is a shorthand for `topLevelDomain(...)`,
  available everywhere the long form is.
- **F-TLD-4.** The catalogue is *informational by default*. We do
  NOT auto-reject hosts that end with an unknown suffix unless the
  caller opts into `URLBuildConfiguration.strict` (see F-Cfg-1).
- **F-Cfg-1.** `URLBuildConfiguration` carries a `tldEnforcement` knob
  (`.off` default, `.strict` opt-in). Both entry points accept it.
  Strict mode rejects composed `tld(...)` values that are not in the
  ICANN catalogue and host strings without a longest-match ICANN
  suffix; IPv4 and IPv6 literals remain exempt.

### 3.5 Userinfo

- **F-Userinfo-1.** Userinfo declarations are rejected by default.
  `URLBuildConfiguration.userInfoPolicy` carries the only opt-in.
- **F-Userinfo-2.** `.usernameOnly` permits a username without a
  password. `.usernameAndPassword` permits both fields and keeps the
  credential-bearing policy visible at the call site.
- **F-Userinfo-3.** Userinfo requires an authority host. It cannot be
  declared on opaque/custom-scheme URLs that have no host.
- **F-Userinfo-4.** Raw username/password fields are percent-encoded
  as URI userinfo subcomponents. Delimiters such as `:`, `@`, `/`,
  `?`, `#`, and `%` are encoded from raw input so they cannot change
  the authority grammar.
- **F-Userinfo-5.** Empty usernames, forbidden IRI scalars, duplicate
  userinfo declarations, and userinfo host back-doors are rejected.
  Userinfo-related errors do not include the raw username or password.

### 3.6 Errors

- **F-Error-1.** All validation failures surface as a single closed
  `URLBuildError` enum with `Equatable + Sendable + CustomStringConvertible`
  conformance.
- **F-Error-2.** `withThrowingURL` uses Swift typed throws
  (`throws(URLBuildError)`).

### 3.7 Macros

- **F-Macro-1.** `#URL { … }` expands to `URLBuilder { … }` and
  supports the same explicit `URLBuildConfiguration` argument.
- **F-Macro-2.** `@URLQuery` synthesizes `URLQueryRepresentable`
  conformance for stored properties on structs, classes, and actors.
  Shape is inferred structurally from each binding's type:
  - a scalar renders as `Query(key, value)`;
  - a single optional layer (`T?`) unwraps with `if let` (omitted when nil);
  - `[T]` / `Array<T>` and `Set<T>` unfold to one query item per element,
    with `Set` iteration emitted in a deterministic sorted order;
  - an optional collection (`[T]?`, `Set<T>?`) is unwrapped first, then
    unfolded.
- **F-Macro-3.** `@Query(.key("..."))`, `@Query(.flag)`, and
  `@Query(.ignore)` customize `@URLQuery` property rendering without
  generating runtime code by themselves.
- **F-Macro-4.** `@URLQuery` skips members that are not per-instance query
  state — `static`/`class` (type-level) and `lazy` storage, and computed
  properties — while keeping stored properties that have `willSet`/`didSet`
  observers. Every binding of a multi-binding declaration (`let a, b: Int`)
  is emitted, with a trailing type annotation propagated to earlier bindings.
- **F-Macro-5.** Shapes with no canonical query unfold are diagnosed at
  compile time rather than guessed (fail-fast): a dictionary property, a
  nested optional (`T??`), and an un-annotated collection literal (which would
  otherwise silently JSON-encode rather than unfold — an explicit `[T]` /
  `Set<T>` annotation is required). A keyword-named property (`` let `default` ``)
  is backtick-escaped in the expansion so it compiles and renders under its
  bare name.

---

## 4. Standards Compliance Requirements

We build the DSL around the published standards rather than a single
opinionated dialect. The per-feature coverage breakdown lives in
`Appendix-StandardsCoverage.md`. The standards in scope are:

| Standard | Scope |
|---|---|
| **RFC 3986** (STD 66) | Generic URI syntax, authority, percent-encoding, dot segments, security considerations |
| **RFC 3987** | Internationalised Resource Identifiers and IRI→URI mapping |
| **RFC 1035 + 1123** | DNS preferred-syntax, label length, digit-leading allowance |
| **RFC 3492** | Punycode (Bootstring) used by IDNA `toASCII` |
| **RFC 4291 + 5952** | IPv6 text forms and canonical representation |
| **RFC 5890–5894** | IDNA2008 — U-label/A-label, lookup processing, codepoint classification, Bidi |
| **RFC 5892** | IDNA codepoint categories (PVALID / CONTEXTJ / CONTEXTO / DISALLOWED / UNASSIGNED) |
| **RFC 6335** | IANA port assignment (port 0 reserved) |
| **RFC 6943 §3.4** | Identifier comparison where percent-decoded equivalence affects dot-segment security |
| **RFC 7595** | URI scheme syntax / registration guidelines |
| **RFC 9110** | `http`/`https` URI schemes, default ports, host case, §11.7.6 header injection |
| **RFC 9844** | IPv6 zone identifiers are UI input only (obsoletes RFC 6874) |
| **RFC 2606 / 6761 / 6762 / 7686 / 8375 / 9476** | Special-use and reserved domain names |
| **ISO/IEC 10646** | Universal Coded Character Set (UCS) — codepoint property data backing IDNA classification |
| **WHATWG URL Standard** | Documented as a divergence baseline, not a target |
| **IANA Root Zone Database** | Canonical list of currently delegated TLDs |
| **Mozilla Public Suffix List (ICANN section)** | Multi-label public-suffix canonical list |

ABNF notation RFCs (RFC 5234 / 7405) and URI design/ownership guidance
(RFC 7320 / 8820) are cited as background only; they do not impose
additional producer obligations on URLBuilder. The appendix lists them
explicitly as out of scope.

Local copies of every cited RFC live at `docs/References/RFCs/`.
The Unicode UCD lives at `docs/References/ISO-IEC/`. The IANA
TLD list and the Mozilla PSL live at `docs/References/TLDs/`.
The WHATWG URL Standard lives at `docs/References/WHATWG/`.

---

## 5. Security Requirements

By construction, the DSL mitigates:

- **S-Userinfo.** Userinfo is disabled by default. RFC 3986 §3.2.1
  and RFC 9110 §4.2.4 deprecate password-style userinfo, so callers
  must choose `.usernameOnly` or `.usernameAndPassword` explicitly.
  We reject composed hosts containing `@` so the back-door is closed,
  and userinfo errors do not echo raw credential values.
- **S-CRLF.** C0 controls (CR/LF/NUL/etc.) are rejected in path
  segments, query names, query values, and fragments. This blocks the
  RFC 9110 §11.7.6 URI-based header-injection class.
- **S-DotSegments.** Literal `.` and `..` path segments are rejected.
  Percent-encoded dot segments (`%2e`, `%2e%2e`) are decoded once and
  re-checked, per RFC 3986 §5.2.4 + RFC 6943 §3.4.
- **S-Backslash.** Path segments containing `\` are rejected (RFC 3986
  §3.3 pchar excludes backslash; WHATWG normalises it for browsers —
  we do not).
- **S-PortZero.** Port range is `1...65_535`. Port 0 is reserved by
  RFC 6335 §6 and rejected.
- **S-IDNA.** Codepoints DISALLOWED by RFC 5892 §2.4 — symbols (Sm/Sc/
  Sk/So including emoji), punctuation (Pc/Pd/Ps/Pe/Pi/Pf/Po),
  separators (Zs/Zl/Zp), other (Cc/Cf/Cs/Co/Cn), non-characters
  (FDD0..FDEF, *FFFE/*FFFF) — are rejected before Foundation IDNA is
  consulted, because Foundation Punycode-encodes some §2.4 scalars
  instead of rejecting them outright.
- **S-IPv6Zone.** RFC 9844 §4: zone identifiers (`fe80::1%en0`) are
  UI-only input; URI host literals MUST NOT contain them.
- **S-DangerousSchemes.** `javascript:`, `data:`, `file:`, `vbscript:`
  are application-policy concerns. The DSL accepts them syntactically
  (they are valid per RFC 3986 §3.1) and a regression test pins
  acceptance — applications decide their own scheme allow-list.

---

## 6. Internationalisation Requirements

- **I-1.** Hosts are accepted as Unicode (U-labels) and converted to
  A-labels via Punycode (RFC 5891 §4 / RFC 3492).
- **I-2.** Labels are NFC-normalised before IDNA classification (RFC
  5891 §5.4).
- **I-3.** ucschar codepoints in path/query are percent-encoded via
  UTF-8 (RFC 3987 §3.1).
- **I-4.** RFC 5892 §2.2 CONTEXTJ (ZWJ/ZWNJ) and §2.3 CONTEXTO are
  enforced through the IDNA path; the observable rejection outside the
  contextual rules is pinned by tests.

---

## 7. Tooling and Automation Requirements

- **T-1 — TLD generator is a SwiftPM build tool plugin.**
  `PublicSuffixGeneratorPlugin` regenerates the public-suffix
  catalogue before every URLBuilder compile, sourced from the IANA
  Root Zone Database and the ICANN section of the Mozilla PSL. The
  generator itself is a Swift library (`PublicSuffixGeneratorCore`)
  with its own test target, wrapped by a thin executable
  (`public-suffix-generator`) that the plugin invokes.
- **T-2 — No hand-curated catalogues.** The catalogue MUST come from
  the canonical upstream sources. The generator output is not
  committed; only the upstream inputs are vendored.
- **T-3 — Reproducible builds.** The generator pins the upstream
  version + commit hash in the file header so a regeneration can be
  diffed deterministically. The plugin declares the upstream files as
  inputs, so SwiftPM only re-runs it when they change.
- **T-4 — Formatter configuration is part of the baseline.** The
  repository includes `.swift-format`, derived from Swift 6.3
  `swift-format` defaults and amended for 4-space indentation,
  4-space tab width, indented switch cases, and uppercase DSL entry
  points.

---

## 8. Testing Requirements

- **TS-1.** Tests are organised by RFC clause / scope, one file per
  spec area, under `Tests/URLBuilderTests/RFCCompliance/`.
- **TS-2.** Standards tests cite the exact RFC clause they exercise in
  the test name or the surrounding test context. Each file header lists
  the local spec paths it references.
- **TS-3.** Security-relevant behaviours are pinned by tests under
  `Tests/URLBuilderTests/SecurityComplianceTests.swift`.
- **TS-4.** Rejected security behaviours are green tests; accepted
  behaviours are documented as pinned current behaviour.
- **TS-5.** Foundation behaviour we depend on (Punycode, IDNA, IPv6
  canonicalisation, default port omission) is pinned by tests so a
  Foundation regression or platform divergence is caught at build
  time, not in production.
- **TS-6.** WHATWG-divergence pins (`WHATWG_URLDivergence.swift`)
  document each conscious deviation from the WHATWG URL Standard.

---

## 9. Documentation Requirements

- **D-1.** `docs/Standards.md` — the standards we follow and
  the rationale behind each public API decision.
- **D-2.** `docs/Requirements.md` — this file.
- **D-3.** `docs/Appendix-StandardsCoverage.md` — per-feature
  coverage appendix listing the standards that back each guarantee and
  the test that locks it in.
- **D-4.** `docs/References/` — local copies of every cited
  RFC, the Unicode UCD, the IANA Root Zone TLD list, the Mozilla
  Public Suffix List, and the WHATWG URL Standard, so readers can
  read the source text without leaving the repository.
- **D-5.** Standards test names or surrounding test context carry inline
  RFC citations so readers do not have to bounce between files.

---

## 10. Decisions We Locked

These are the explicit current design decisions:

1. **Permissive host validation by default — including `http`/`https`.**
   Strict-mode presets are available but never apply by default.
   Rationale: corporate and home-network deployments expose custom
   TLDs (`.corp`, `.lan`, …) that strict policies break.
2. **Userinfo is opt-in and password-capable userinfo is separately
   opt-in.** Username/password declarations exist for legacy
   integrations, but the default configuration rejects all userinfo,
   and `.usernameOnly` still rejects password values. Userinfo errors
   never echo raw values.
3. **Public-suffix catalogue is informational by default and enforces
   on opt-in.** We never auto-reject an unknown suffix unless the
   caller passes `URLBuildConfiguration.strict` (or sets
   `tldEnforcement = .strict`). The catalogue is the source of truth
   when strict mode is engaged.
4. **`tld(...)` is offered as a shorthand for `topLevelDomain(...)`.**
   We keep both names so the long form can be used in code that
   prioritises readability and the short form in code that prioritises
   density.
5. **Foundation is the IDNA / IPv6 backbone.** Where Foundation
   diverges from a spec (RFC 5892 §2.4 emoji, IPv6 zone IDs, etc.),
   we pre-check before handing input to Foundation. Tests pin the
   observable outcome to catch future Foundation regressions.
6. **Multi-label public suffixes compose at the call site.**
   Hand-curating thousands of camelCase names would be hostile and
   arbitrary; chaining labels (`TLD.co.uk`, `TLD.com.au`) keeps each
   label distinct and is validated against the PSL only when strict
   mode is engaged.

---

## 11. Glossary

- **A-label.** ASCII Compatible Encoding (ACE) form of an IDN label,
  prefixed `xn--` (RFC 5890 §2.3.2.1).
- **U-label.** Unicode form of an IDN label.
- **LDH.** Letter-Digit-Hyphen rule from RFC 1035 §2.3.1.
- **PSL.** Mozilla Public Suffix List
  (`https://publicsuffix.org/list/public_suffix_list.dat`).
- **gTLD / ccTLD.** Generic / country-code top-level domain.
- **pchar.** Path-character set defined by RFC 3986 §3.3.
- **CONTEXTJ / CONTEXTO.** RFC 5892 §2.2/§2.3 codepoint categories
  whose validity depends on a contextual rule.
- **ucschar.** Unicode characters allowed in IRIs but not URIs (RFC
  3987 §2.2). Mapped to UTF-8 percent-encoding when an IRI is
  converted to a URI.

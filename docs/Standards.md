# Standards

This document records the standards we target and the rationale behind
every public API decision. The companion documents are:

- [`Requirements.md`](Requirements.md) — the requirements that shaped
  the package and the current design decisions.
- [`Appendix-StandardsCoverage.md`](Appendix-StandardsCoverage.md) —
  appendix listing the quality guarantees the package delivers, the
  standard that backs each one, and the test that locks it in.
- [`References/`](References/) — local copies of every cited RFC,
  the Unicode UCD, the IANA Root Zone TLD list, the Mozilla Public
  Suffix List, and the WHATWG URL Standard.

## URL, URI, and ISO

There is no single ISO standard that defines "URL declaration" syntax. The
current generic syntax for URLs/URIs is IETF RFC 3986, published as STD 66.
Internationalized Resource Identifiers are defined by RFC 3987 and use the
Universal Character Set from Unicode / ISO/IEC 10646. Internationalized
domain names are covered by the IDNA RFCs, including RFC 5890.

## Sources We Build On

- Apple Foundation `URLComponents`: constructs and parses URL components
  according to RFC 3986. We build every URL through it instead of by
  string concatenation, which is the most direct way to inherit
  Foundation's percent-encoding and ordering guarantees.
- Apple Foundation `URLQueryItem` and `URLComponents.queryItems`:
  preserve query item order, permit repeated names, and distinguish
  nil values from empty values.
- Apple Foundation `URLComponents.url`: returns nil when component
  rules cannot form a URL, including the path rules that apply when
  an authority component is present. We surface that refusal as an
  error rather than swallowing it.
- RFC 3986: generic URI grammar, authority/host syntax, percent
  encoding, path, query, fragment, and security considerations.
- RFC 3987: IRI syntax and mapping to URI syntax, using Unicode /
  ISO/IEC 10646.
- RFC 1035 + RFC 1123: DNS label preferred-syntax (LDH) and the
  RFC 1123 §2.1 digit-leading allowance.
- RFC 3492: Punycode (Bootstring) encoding used by IDNA toASCII.
- RFC 4291 + RFC 5952: IPv6 text forms and canonical representation,
  including embedded-IPv4 forms (§2.5.5 / §5).
- RFC 5890 and RFC 5891: IDNA definitions, U-label/A-label processing,
  and Punycode conversion for internationalized domain names.
- RFC 5892: IDNA codepoint classification (PVALID / CONTEXTJ /
  CONTEXTO / DISALLOWED / UNASSIGNED) backed by Unicode / ISO/IEC 10646.
- RFC 5893: Bidirectional rules for IDN labels.
- RFC 6335: Internet port assignment (port 0 reserved).
- RFC 6943 §3.4: Issues in identifier comparison where
  percent-decoded equivalence affects dot-segment security.
- RFC 9110: `http` and `https` URI schemes, default ports, host/scheme
  case normalization, empty path equivalence, and §11.7.6 URI-based
  header-injection guidance.
- RFC 9844: IPv6 zone identifiers are UI input; obsoletes RFC 6874
  and reverts RFC 6874's URI syntax update.
- RFC 7595: URI scheme syntax guidelines and registration
  considerations.
- RFC 2606 / 6761 / 6762 / 7686 / 8375 / 9476: special-use and
  reserved domain names (`.test`, `.example`, `.invalid`,
  `.localhost`, `.local`, `.onion`, `.home.arpa`, `.alt`).
- IANA Root Zone Database: complete list of currently delegated
  top-level domains. Mirrored at
  `docs/References/TLDs/tlds-alpha-by-domain.txt`.
- Mozilla Public Suffix List (ICANN section): canonical list of
  public suffixes including multi-label entries (`co.uk`, `com.au`, …).
  Mirrored at `docs/References/TLDs/public_suffix_list.dat`.
- WHATWG URL Standard: living web-platform URL behavior. We mirror it
  at `docs/References/WHATWG/url.html` purely as a divergence
  baseline.

Out-of-scope references:

- RFC 5234 and RFC 7405 define ABNF notation used by other RFCs; they
  do not add URL producer behaviour.
- RFC 7320 and RFC 8820 are URI design and ownership guidance; they
  inform API restraint but are not compliance targets for emitted URLs.

## API Decisions

### Construction model

- We build through `URLComponents` instead of manual string
  concatenation, so percent-encoding and component-validation are
  inherited rather than re-implemented.
- We expose `URLBuilder { ... } -> URL` for static declarations and
  `withThrowingURL { ... } throws(URLBuildError) -> URL` for runtime
  input, so callers pick the failure mode that fits the call site.
- We expose `#URL { ... }` as freestanding macro syntax for the
  trapping contract. It expands to the same `URLBuilder` call, including
  the optional explicit configuration argument.

### Schemes

- We keep `HTTP` and `HTTPS` as first-class declarations because they
  require a host in this DSL and benefit from authority-prefix
  enforcement.
- We allow custom schemes through
  `URLDeclaration(scheme: Scheme("myapp"))`, normalised to lowercase
  per RFC 3986 §6.2.2.1.

### Hosts

- We model composed DNS hosts with `.subdomain`, `.domain`, and
  `.topLevelDomain`, while also allowing complete hosts through `Host`
  / `HTTPS("...")`, IPv6 literals through `IPv6` / `Host.ipv6`, and IP
  literals through `IPLiteral` / `Host.ipLiteral`. Each composed piece
  is a separate DNS label, so callers don't accidentally pack multiple
  labels into one string.
- We add compact typed-host declarations such as
  `Host { .subdomain("www").domain("example").topLevelDomain(.com) }`
  so callers can avoid string-packed hosts entirely.
- We add dedicated result builders for host labels, path segments, and
  query DTOs. For example, `Host { "www"; "example"; TLD.com }` keeps
  each DNS label distinct, `Path { "tickets"; "123" }` treats each
  string as one segment, and `@URLQueryBuilder` keeps DTO query output
  on explicit `Query` declarations.
- We keep complete-host string overloads such as
  `HTTPS("www.example.com") { ... }` as escape hatches for hosts that
  arrive as a single string from external input.
- We keep concise capitalized component declarations (`Host`, `Path`,
  `Query`, `Fragment`, `Domain`, `TLD`) so simple URLs stay readable
  while each piece remains typed.
- We provide `tld(...)` as a shorthand for `topLevelDomain(...)`
  everywhere the long form is available so callers can choose
  between readability and density.
- In `Host { ... }`, string labels are unclassified. When a TLD is
  present and no explicit `Domain` was declared, the last string label
  is inferred as the registered domain and earlier strings become
  subdomains. Without a TLD, string labels form a complete host string
  and pass through host-string validation.
- We support IPvFuture literals through `IPvFuture` for RFC 3986
  completeness.
- We canonicalize IPv6 literals to RFC 5952 form before they reach
  the URL.

### TLDs and public suffixes

- We generate the public-suffix catalogue from the IANA Root Zone
  Database and the ICANN section of the Mozilla Public Suffix List
  through a SwiftPM build tool plugin
  (`PublicSuffixGeneratorPlugin`) that runs before every URLBuilder
  compile. The generated module exposes:
  - One constant on `TopLevelDomain` per IANA single-label TLD.
  - `PublicSuffix.icannTLDs` — the set of every IANA single-label TLD.
  - `PublicSuffix.icannSuffixes` — the literal ICANN public-suffix
    rules, including multi-label entries (`co.uk`, `com.au`,
    `home.arpa`, …).
  - `PublicSuffix.icannWildcardParents` and
    `PublicSuffix.icannExceptions` — PSL wildcard parent and exception
    rules preserved separately so Algorithm 5.1 semantics are not lost.
  - `PublicSuffix.contains(_:)` and `PublicSuffix.longestMatch(for:)`
    for callers who want to layer policy on top of the catalogue.
- We expose multi-label public suffixes by chaining labels onto a TLD
  (`TLD.co.uk`, `TLD.com.au`, `TLD.aichi.nagoya`). The first hop is a
  real IANA constant; further hops compose at the call site, and the
  resulting raw value is checked against the catalogue only when the
  caller opts into strict configuration. We chose composition over
  hand-curated multi-label constants because thousands of camelCased
  names would be arbitrary and brittle.
- We offer `URLBuildConfiguration` with a `tldEnforcement` knob (`.off`
  default per Requirements §10.3, `.strict` opt-in). Strict mode
  rejects composed `tld(...)` values absent from the catalogue and
  host strings without a longest-match ICANN suffix; IPv4 and IPv6
  literals remain exempt.

### Paths, queries, fragments

- We normalise default ports by omitting `:80` for HTTP and `:443` for
  HTTPS so the rendered URL stays canonical.
- We preserve absent HTTP path as absent, while allowing `Path("")` to
  explicitly render `/`. RFC 9110 treats empty path and `/` as
  equivalent and recommends `/` as normal form, but we keep
  declaration intent visible at the call site.
- We preserve query ordering and repeated names by mapping directly to
  `URLQueryItem`.
- We separate query flags (`?preview`) from empty query values
  (`?preview=`).
- We keep repeated query keys by default. `URLBuildConfiguration` offers
  opt-in `.firstWins` and `.lastWins` deduplication policies for
  integrations that expect map-like query semantics; both policies keep
  the first occurrence's rendered position.
- We render a typed query value one of two ways. A value conforming to
  `URLQueryValueConvertible` — `Bool`, the integer and floating-point types,
  `Decimal` (via its base-10 `description`, avoiding binary-float rounding),
  `String`, `Substring`, `UUID`, `Date`, and `RawRepresentable` over a
  convertible raw value — renders as a plain value. Any other `Encodable`
  value renders as compact JSON (sorted keys, slashes unescaped) via
  [ADJSON](https://github.com/g-cqd/ADJSON), which `URLComponents` then
  percent-encodes. When a type satisfies both, the convertible path wins.
- We expose `URLQueryRepresentable` for DTOs that expand to multiple
  query items. The `@URLQuery` macro can synthesize that conformance
  from stored properties, and `@Query(.key)`, `@Query(.flag)`, and
  `@Query(.ignore)` customize individual properties. Optional properties are
  omitted when `nil`; `[T]` and `Set<T>` unfold to repeated keys, with `Set`
  iteration emitted in a deterministic sorted order for stable URLs.

### Userinfo

- We keep userinfo disabled by default. RFC 3986 §3.2.1 permits the
  generic syntax, but it also deprecates `user:password` userinfo and
  calls out clear-text credential risk. RFC 9110 §4.2.4 deprecates
  userinfo for `http(s)` URIs.
- We expose userinfo only through explicit declarations and
  `URLBuildConfiguration.userInfoPolicy`. `.usernameOnly` permits a
  username without a password. `.usernameAndPassword` permits both and
  is intentionally named so call sites show the credential-bearing
  choice.
- We encode raw username/password fields through
  `URLComponents.percentEncodedUser` and
  `URLComponents.percentEncodedPassword`, using a conservative
  unreserved-character pass-through. Delimiters such as `:`, `@`, `/`,
  `?`, `#`, and `%` are percent-encoded from raw input, so a username
  or password cannot change the authority grammar.
- We reject empty usernames, forbidden IRI scalars, duplicate userinfo
  declarations, and userinfo without a host. `URLBuildError` cases for
  userinfo intentionally do not echo raw userinfo values so secrets are
  not copied into logs.

### Refusals (security)

- We reject empty query names, invalid host labels, invalid IP
  literals, invalid ports, path traversal dot segments, path
  backslashes, and NUL in path/query and fragment declarations.
- We reject IPv6 zone identifiers in URI host literals. RFC 9844 moved
  zone ID handling to UI input and obsoleted RFC 6874's URI syntax
  update.
- We reject userinfo by default, and we reject `@` in host labels and
  complete-host strings so userinfo cannot be smuggled through the
  host grammar. Credential-bearing userinfo exists only behind explicit
  configuration opt-in.

### Macro surface

- `#URL { ... }` and `#URL(configuration: ...) { ... }` are
  freestanding expression macros that forward to `URLBuilder`.
- `@URLQuery` synthesizes `URLQueryRepresentable` conformance for
  structs, classes, and actors by walking stored properties.
- `@Query(.key("..."))`, `@Query(.flag)`, and `@Query(.ignore)` are
  marker attributes read by `@URLQuery`; the marker macro itself
  generates no peers.
- The runtime API remains usable without macros. Macros provide syntax
  and synthesis, not a different validation model.

## RFC Test Coverage

Tests are organised by RFC clause. Backtick test names and nearby test
context cite the exact sections they exercise. See
`docs/Appendix-StandardsCoverage.md` for the per-feature
breakdown of guarantees and the tests that pin them. Local copies of
every cited RFC live in `docs/References/RFCs/`; the
indirect ISO/IEC 10646 dependency is mirrored by the Unicode UCD in
`docs/References/ISO-IEC/`.

### Test files

RFC compliance tests live in `Tests/URLBuilderTests/RFCCompliance/`,
one file per RFC clause / scope:

| File | Spec scope |
|---|---|
| `RFC3986_Characters.swift` | RFC 3986 §2 — percent-encoding, reserved/unreserved sets, hex case, double-encoding; §2 NUL byte rejection |
| `RFC3986_Scheme.swift` | RFC 3986 §3.1 + §6.2.2.1; RFC 7595 §3.8 |
| `RFC3986_Userinfo.swift` | RFC 3986 §3.2.1; RFC 9110 §4.2.4 (deprecated) |
| `RFC3986_HostRegName.swift` | RFC 3986 §3.2.2 reg-name; RFC 1035 §2.3.4 label length |
| `RFC3986_HostIPv4.swift` | RFC 3986 §3.2.2 IPv4address |
| `RFC3986_HostIPv6.swift` | RFC 3986 §3.2.2 IP-literal; RFC 4291 §2.2; RFC 5952 §4.1-§4.3; RFC 9844 §4 (zones) |
| `RFC3986_HostIPvFuture.swift` | RFC 3986 §3.2.2 IPvFuture |
| `RFC3986_Port.swift` | RFC 3986 §3.2.3; RFC 9110 §4.2.1/§4.2.2; RFC 6335 §6 |
| `RFC3986_Path.swift` | RFC 3986 §3.3 + §5.2.4 |
| `RFC3986_Query.swift` | RFC 3986 §3.4 |
| `RFC3986_Fragment.swift` | RFC 3986 §3.5 |
| `RFC9110_HTTPSchemes.swift` | RFC 9110 §4.2 — http(s) default ports, empty path, host case |
| `RFC3987_IRI.swift` | RFC 3987 §3.1; RFC 5890 §2.3; RFC 5891 §4 |
| `RFC5892_IDNAClassification.swift` | RFC 5892 — IDNA codepoint classification (PVALID / DISALLOWED / NFC); ISO/IEC 10646 |
| `RFC5892_CONTEXT.swift` | RFC 5892 §2.2 CONTEXTJ (ZWJ/ZWNJ) + §2.3 CONTEXTO |
| `RFC1035_DNSLabels.swift` | RFC 1035 §2.3.1 / §2.3.4 LDH and length; RFC 1123 §2.1 digit-leading allowance |
| `RFC3492_Punycode.swift` | RFC 3492 § 3 + §6.1 Bootstring encoding; RFC 5890 §2.3.2.1 ACE prefix; RFC 5891 §4.4-§4.5 |
| `RFC5952_EmbeddedIPv4.swift` | RFC 4291 §2.5.5.1/.2 + RFC 5952 §5 — embedded IPv4 in IPv6 |
| `RFC2606_6761_SpecialUseTLDs.swift` | RFC 2606 §2, 6761 §6, 6762 §3, 7686 §2, 8375 §3, 9476 §2 |
| `WHATWG_URLDivergence.swift` | WHATWG URL Standard — divergence pins vs. RFC 3986/3987 |
| `IANA_PublicSuffixCatalog.swift` | IANA Root Zone + Mozilla PSL ICANN — generated catalog smoke + behaviour tests |
| `DSLStructural.swift` | DSL invariants cross-cutting RFC 3986 §3 |

Other test files:

- `Tests/URLBuilderTests/SecurityComplianceTests.swift` — STRIDE-aligned
  security behaviour tests. Rejected behaviours are green tests pinning
  refusal, and accepted behaviours document the current public contract.
- `Tests/URLBuilderTests/URLBuilderTests.swift` — DSL ergonomic tests
  (result-builder shape, conditionals, optionals) annotated with the RFC clause
  they incidentally exercise.
- `Tests/URLBuilderTests/ShorthandTests.swift` — DSL shorthand and query-value
  rendering, including the scalar matrix (`Bool`, `Int`, `Double`, `Decimal`
  via `description`, `String`) and the compact-JSON `Encodable` path via ADJSON.
- `Tests/URLBuilderTests/QueryDeduplicationTests.swift` — opt-in
  query-deduplication policies and their interaction with query flags
  and form URL encoding.
- `Tests/URLBuilderTests/MacroIntegrationTests.swift` and
  `Tests/URLBuilderMacrosTests/` — runtime and expansion coverage for
  `#URL`, `@URLQuery`, and `@Query`.

### ISO/IEC 10646 coverage

The `RFC 5892 — IDNA codepoint classification (ISO/IEC 10646)` suite in
`RFCCompliance/RFC5892_IDNAClassification.swift` exercises the IDNA
categories that RFC 5892 projects from Unicode/ISO 10646: PVALID
(§2.1), DISALLOWED (§2.4 — emoji, currency/math/modifier symbols,
punctuation, non-characters, C0 controls), and the RFC 5891 §5.4 NFC
normalisation requirement. We pre-check Unicode general categories
before handing the label to Foundation IDNA, because Foundation
Punycode-encodes some §2.4-DISALLOWED scalars instead of rejecting
them.

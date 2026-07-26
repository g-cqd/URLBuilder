# References — Index

Standards corpus for the `URLBuilder` Swift library. All files are local
copies; URLs are recorded for traceability only.

## IETF RFCs

Each RFC is downloaded as both `.txt` (canonical) and `.html` (rendered).

### Core URI grammar and registration

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **3986** | Uniform Resource Identifier (URI): Generic Syntax — STD 66 | `RFCs/rfc3986.txt` | The core grammar. Governs scheme / authority / host / port / path / query / fragment, percent-encoding, dot-segments, IP-literal, IPv6, IPvFuture, security considerations. Most of the DSL maps directly to this. |
| **3987** | Internationalized Resource Identifiers (IRIs) | `RFCs/rfc3987.txt` | Allows non-ASCII characters in URIs by mapping to UCS (ISO/IEC 10646). Relevant whenever a host label, path segment, or query value contains non-ASCII text. |
| **6570** | URI Template | `RFCs/rfc6570.txt` | §1.2 / §2 / §3.2 — template-expansion semantics. Forward reference for any future template-expansion API on the builder. |
| **7320** | URI Design and Ownership — BCP 190 | `RFCs/rfc7320.txt` | Best practice on who owns the URI structure of a service. Informs DSL ergonomics. |
| **7595** | Guidelines and Registration Procedures for URI Schemes | `RFCs/rfc7595.txt` | Defines well-formed URI schemes — what `scheme("...")` should accept. |
| **8820** | URI Design and Ownership — BCP 190 (Updated) | `RFCs/rfc8820.txt` | Companion / update to RFC 7320. |

### ABNF metalanguage

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **5234** | Augmented BNF for Syntax Specifications: ABNF — STD 68 | `RFCs/rfc5234.txt` | The metalanguage used by RFC 3986/3987/9110 grammars. |
| **7405** | Case-Sensitive String Support in ABNF | `RFCs/rfc7405.txt` | Defines `%s"..."` / `%i"..."` literal syntax used by RFC 9110 grammars. |

### Encoding (UTF-8 / Unicode / IDNA2008)

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **3629** | UTF-8, a transformation format of ISO 10646 — STD 63 | `RFCs/rfc3629.txt` | §3 — encoding form referenced normatively by RFC 3986 §2.5 and RFC 3987 §3.1; defines the byte sequence percent-encoding operates on. |
| **5890** | IDNA Definitions and Document Framework | `RFCs/rfc5890.txt` | IDNA2008 framework. Defines U-label / A-label terminology used in host normalization. |
| **5891** | IDNA Protocol | `RFCs/rfc5891.txt` | Registration and lookup processing for internationalized labels. |
| **5892** | IDNA Code Points | `RFCs/rfc5892.txt` | Classifies every Unicode code point as PVALID / DISALLOWED / CONTEXTJ / CONTEXTO. Backed by Unicode / ISO/IEC 10646. |
| **5893** | Right-to-Left Scripts for IDNA | `RFCs/rfc5893.txt` | Bidi rule for label composition (referenced by 5891). |
| **5894** | IDNA Background, Explanation, Rationale | `RFCs/rfc5894.txt` | Informational rationale for IDNA2008. |
| **3492** | Punycode | `RFCs/rfc3492.txt` | A-label encoding algorithm used by IDNA2008. |
| **8264** | PRECIS Framework for Internationalized Strings | `RFCs/rfc8264.txt` | §5–§9 — preparation / enforcement / comparison rules for non-host internationalized strings (query values, fragment text). |

### DNS host names

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **1034** | Domain Names — Concepts and Facilities — STD 13 | `RFCs/rfc1034.txt` | §3.1 / §3.5 — original DNS label tree, label/FQDN length constraints. |
| **1035** | Domain Names — Implementation and Specification — STD 13 | `RFCs/rfc1035.txt` | §2.3.1 / §2.3.4 — label syntax, 63-octet / 253-octet limits. |
| **1123** | Requirements for Internet Hosts — Application and Support | `RFCs/rfc1123.txt` | §2.1 — relaxes RFC 1035's leading-letter rule, allows leading digit. |

### IP literals

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **4291** | IPv6 Addressing Architecture | `RFCs/rfc4291.txt` | Defines IPv6 address syntax and the canonical text form referenced by RFC 3986 §3.2.2. |
| **5952** | A Recommendation for IPv6 Address Text Representation | `RFCs/rfc5952.txt` | Canonical text form for IPv6 literals — what URLBuilder produces when canonicalizing. |
| **6874** | Representing IPv6 Zone Identifiers in URIs (**OBSOLETED**) | `RFCs/rfc6874.txt` | Historical. Kept for reference because RFC 9844 references it. URLBuilder rejects zone IDs in URIs per RFC 9844. |
| **9844** | IPv6 Zone Identifiers in URIs | `RFCs/rfc9844.txt` | Obsoletes RFC 6874. Says zone IDs are UI input only and MUST NOT appear in URI host literals. URLBuilder enforces this. |
| **6943** | Issues in Identifier Comparison for Security | `RFCs/rfc6943.txt` | Equivalence / comparison pitfalls for IRIs and IDNs — informs how strict the DSL should be on host normalisation. |

### Port

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **6335** | IANA Procedures for Port Number Registry — BCP 165 | `RFCs/rfc6335.txt` | §6 — TCP/UDP port range 1..65535 (port 0 reserved). |

### Scheme-specific RFCs

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **9110** | HTTP Semantics | `RFCs/rfc9110.txt` | §4.2 defines `http` and `https` URI schemes, default ports (80/443), case normalisation, empty-path equivalence. URLBuilder's `http`/`https` blocks must follow this. |
| **8089** | The 'file' URI Scheme | `RFCs/rfc8089.txt` | §2 / §3 / Appendix A — current normative spec for `file:` URIs. Forward reference for `file { ... }` support. |
| **6068** | The 'mailto' URI Scheme | `RFCs/rfc6068.txt` | §2 / §5 / §6 — `mailto:` syntax and CR/LF injection mitigation in header fields. Forward reference for `mailto { ... }` support. |
| **5321** | Simple Mail Transfer Protocol | `RFCs/rfc5321.txt` | §4.1.2 — `addr-spec` grammar referenced by RFC 6068. Only relevant once `mailto:` lands. |

### Special-use names

| RFC | Title | Local file | Why it matters to URLBuilder |
|---|---|---|---|
| **2606** | Reserved Top Level DNS Names | `RFCs/rfc2606.txt` | `.test` / `.example` / `.invalid` / `.localhost`. |
| **6761** | Special-Use Domain Names | `RFCs/rfc6761.txt` | IANA Special-Use Domain Name registry. |
| **6762** | Multicast DNS | `RFCs/rfc6762.txt` | `.local` resolution semantics. |
| **7686** | The .onion Special-Use Domain Name | `RFCs/rfc7686.txt` | Tor hidden service names. |
| **8375** | Special-Use Domain `home.arpa.` | `RFCs/rfc8375.txt` | Home-network special-use name. |
| **9476** | The .alt Special-Use Top-Level Domain | `RFCs/rfc9476.txt` | Pseudo-TLD for non-DNS names. |

## ISO / IEC

The official ISO/IEC 10646:2020 PDF is paywalled (CHF 199 at the ISO Store).
The folder gathers the best free substitutes — full Final Committee Drafts
hosted by Unicode.org, sample chapters from the published edition (iTeh),
amendment work-in-progress, and the Unicode Character Database that operates
as the working form of the standard. See `ISO-IEC/README.md` for full
sourcing notes.

| Document | Local file | What it is |
|---|---|---|
| ISO/IEC 10646:2020 (6th ed.) FCD | `ISO-IEC/iso-iec-10646-2020-FCD-unicode.org.pdf` | Full Final Committee Draft of the published 6th edition (3 MB). |
| ISO/IEC 10646:2007 (5th ed.) FCD | `ISO-IEC/iso-iec-10646-2007-FCD-WG2-N3275.pdf` | Earlier-edition full FCD for diff/historical reference. |
| ISO/IEC 10646:2020 published sample | `ISO-IEC/iso-iec-10646-2020-iteh-sample.pdf` | First chapters of the published 6th edition. |
| ISO/IEC 10646:2020 Amd 1 (2023) sample | `ISO-IEC/iso-iec-10646-2020-amd1-2023-iteh-sample.pdf` | Amendment 1 preview. |
| ISO/IEC 10646:2020 Amd 2 CDAM2.3 chart | `ISO-IEC/iso-iec-10646-2023-amd2-chart.pdf` | Draft chart of additions for Amd 2. |
| Unicode 16.0 Appendix C | `ISO-IEC/unicode-16.0-appendix-C-relationship-ISO-10646.html` | Formal mapping Unicode 16.0 ↔ ISO/IEC 10646:2020+Amd1+Amd2. |
| Unicode/ISO 10646 FAQ | `ISO-IEC/unicode-iso10646-faq.html` | Authoritative explanation of why Unicode UCD = working form of ISO/IEC 10646. |
| Unicode Character Database | `ISO-IEC/UnicodeData.txt`, `DerivedCoreProperties.txt`, `IdnaMappingTable.txt`, `UCD-ReadMe.txt` | The data Foundation actually uses for IDNA2008. |
| Unicode TR#46 (UTS#46) — IDNA Compatibility Processing | `ISO-IEC/unicode-tr46-idna-compatibility-processing.html` | What Foundation's IDNA path actually implements. Documents the deviation from strict RFC 5891 toASCII. |

### Out-of-scope ISO/IEC standards (intentionally not vendored)

A URL builder targeting RFC 3986/3987/9110 has no normative dependency on
the following standards. They are listed here so the boundary is explicit
and so a future contributor doesn't add them speculatively.

| Standard | Reason for exclusion |
|---|---|
| ISO 3166-1 alpha-2 (country codes) | The IANA Root Zone Database (`TLDs/tlds-alpha-by-domain.txt`) is the operational authority for ccTLD shape. ICANN derives candidates from ISO 3166-1 but acts independently per the ccTLD Delegation Policy (`TLDs/icann-cctld-delegation-policy.html`). |
| ISO 639-1/2/3 (language codes) | Language tags appear in HTTP `Accept-Language`, not in URI structure. BCP 47 is the relevant spec, but only inside applications, not the builder. |
| ISO/IEC 14651 (international string ordering) | Collation problem. URL construction does not collate. |
| ISO/IEC 8859-1 (Latin-1) | Pre-RFC 3986 legacy. RFC 3986 §2.5 + RFC 3987 §3.1 mandate UTF-8 (RFC 3629). |
| ISO/IEC 27001 / 27002 (ISMS) | Process standard, not output constraint. |
| ISO/IEC 9075 (SQL), ISO/IEC 80000-13 (binary prefixes) | Unrelated subject matter. |

## Coverage map — RFC clauses governing each DSL surface

| URLBuilder surface | Primary clause | Supporting |
|---|---|---|
| `scheme("...")` | RFC 3986 §3.1 (scheme grammar) | RFC 7595 (registration) |
| `http { ... }` / `https { ... }` | RFC 9110 §4.2 (http/https schemes) | RFC 3986 §3.1 |
| `host { ... }` (DNS labels) | RFC 3986 §3.2.2 (reg-name) | RFC 5890–5894 (IDNA) |
| `subdomain` / `domain` / `topLevelDomain` | RFC 3986 §3.2.2 | DSL convention; not in any RFC verbatim |
| `host(.ipv6(...))` | RFC 3986 §3.2.2 (IP-literal) | RFC 4291, RFC 5952 (canonical form) |
| `host(.ipLiteral(...))` (IPvFuture) | RFC 3986 §3.2.2 (IPvFuture) | — |
| Reject `%25...` zone IDs in IPv6 host | RFC 9844 §4 | RFC 6874 (obsoleted) |
| `port(...)` | RFC 3986 §3.2.3 | RFC 9110 §4.2.1/4.2.2 (default ports) |
| `path { ... }` | RFC 3986 §3.3 (path) | RFC 9110 §4.2.3 (empty path) |
| Reject `..` / `.` segments | RFC 3986 §3.3 (dot-segments), §5.2.4 | — |
| Reject `\` in path | RFC 3986 §2.2/§3.3 (allowed pchar set) | — |
| Reject NUL / control bytes | RFC 3986 §2 (general), §3.4/§3.5 | — |
| `queries { ... }` / `query(...)` | RFC 3986 §3.4 | — |
| Reject empty query name | DSL convention; RFC 3986 leaves it open | — |
| `fragment(...)` | RFC 3986 §3.5 | — |
| Percent-encoding | RFC 3986 §2.1, §2.4 | — |
| Userinfo opt-in policy | RFC 3986 §3.2.1 (security note) | RFC 9110 §4.2.4 |
| Internationalised input | RFC 3987 | RFC 5890/5891/5892, ISO/IEC 10646 |

## TLDs and public suffixes

| Document | Local file | What it is |
|---|---|---|
| IANA Root Zone Database | `TLDs/tlds-alpha-by-domain.txt` | Canonical list of currently delegated TLDs. |
| Mozilla Public Suffix List | `TLDs/public_suffix_list.dat` | ICANN + private public-suffix registry. |
| ICANN ccTLD Delegation policy | `TLDs/icann-cctld-delegation-policy.html` | Documents the relationship between ISO 3166-1 alpha-2 and root-zone ccTLD delegation. ICANN acts independently of ISO 3166/MA. |

The `PublicSuffixGeneratorPlugin` SwiftPM build tool plugin consumes
both files to generate `PublicSuffix.swift` into the build's plugin
work directory before `URLBuilder` compiles.

## WHATWG URL Standard (divergence baseline only)

| Document | Local file | What it is |
|---|---|---|
| WHATWG URL Living Standard | `WHATWG/url.html` | Browser parsing model. URLBuilder documents conscious deviations from this in `Tests/URLBuilderTests/RFCCompliance/WHATWG_URLDivergence.swift` but does not target it. |

## Out of scope (intentionally not downloaded)

- RFC 9111 (HTTP caching), RFC 9112 (HTTP/1.1 wire format) — non-URL parts of HTTP.
- RFC 1738, RFC 2732, RFC 3490 — fully obsoleted predecessors.
- RFC 7230–7235 — obsoleted by RFC 9110/9111/9112.
- RFC 6454 (Origin), RFC 6265 (Cookies) — derived from a parsed URL or applied to a cookie jar; not URI-construction concerns.
- RFC 5322 — message format. Only the `addr-spec` from RFC 5321 §4.1.2 matters for `mailto:`.

## Provenance

All RFCs sourced from `https://www.rfc-editor.org/rfc/rfc{N}.txt` and
`.html`. Initial corpus pulled 2026-05-05; later additions (RFC 1034,
3629, 5321, 6068, 6570, 7405, 8089, 8264 and Unicode TR#46) pulled
2026-05-05. Unicode UCD sourced from
`https://www.unicode.org/Public/UCD/latest/`. ICANN ccTLD policy
sourced from `https://www.icann.org/resources/pages/cctlds-2012-02-25-en`.

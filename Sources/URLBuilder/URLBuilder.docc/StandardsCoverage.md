# Standards Coverage

The standards URLBuilder implements, and where each is enforced.

## Overview

URLBuilder is standards-first: every validation rule traces to a specific clause, and the test
suite is organized by RFC so each guarantee has a named, citable test. The tables below summarize
coverage; the repository's `Documentation/Standards.md` and
`Documentation/Appendix-StandardsCoverage.md` hold the clause-by-clause detail, and
`Documentation/Requirements.md` records the functional requirements.

## Syntax & generic URI

| Standard | Area |
| --- | --- |
| RFC 3986 | Generic URI syntax: scheme, authority, path, query, fragment, percent-encoding |
| RFC 3987 | IRI: forbidden scalars in path/query/fragment |
| RFC 9110 | HTTP semantics: scheme rules, header-injection-safe components |
| WHATWG URL | `application/x-www-form-urlencoded` query rendering; documented divergences |

## Hosts, names & internationalization

| Standard | Area |
| --- | --- |
| RFC 1035 | DNS label and total-length limits |
| RFC 5890–5894 | IDNA2008 framework for internationalized domain names |
| RFC 5892 | DISALLOWED / CONTEXT codepoint classification (pre-IDNA screening) |
| RFC 3492 | Punycode round-trip for U-labels/A-labels |
| RFC 5952 | IPv6 textual representation, including embedded IPv4 |

## Special-use & public suffixes

| Standard | Area |
| --- | --- |
| RFC 2606 / 6761 | Reserved and special-use top-level domains |
| IANA Root Zone | Single-label TLD set (generated) |
| Mozilla PSL | Multi-label public suffixes (generated) |

## Numbers, ports & encoding

| Standard | Area |
| --- | --- |
| RFC 6335 / 9110 §4.2.1 | Port range `1...65535`; port 0 rejected |
| RFC 3629 | UTF-8 well-formedness for component text |
| RFC 8259 (via ADJSON) | Compact JSON rendering of `Encodable` query values (sorted keys) |

## Divergences from WHATWG

URLBuilder intentionally *rejects* inputs that the WHATWG URL Standard would silently repair (for
example, stripping control characters from a host). These divergences are deliberate — failing
loudly is safer for a builder than guessing the author's intent — and are enumerated in the
`WHATWG_URLDivergence` tests.

## See also

- <doc:HostsAndIDNA>
- <doc:PublicSuffixes>
- <doc:Security>

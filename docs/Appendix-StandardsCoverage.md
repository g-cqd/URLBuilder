# Appendix — Standards Coverage

This appendix records the quality guarantees URLBuilder delivers and
the standards that back them. Every guarantee below is locked in by a
test under `Tests/URLBuilderTests/`; the RFC clause is cited inline so
the source text can be reached directly through
`docs/References/`.

The appendix complements `Standards.md` (rationale) and
`Requirements.md` (scope and locked decisions). Local copies of every
cited RFC live at `docs/References/RFCs/`. ISO/IEC 10646 is
mirrored by the Unicode UCD at `docs/References/ISO-IEC/`.
The IANA Root Zone TLD list and the Mozilla PSL live at
`docs/References/TLDs/`. The WHATWG URL Standard archive
lives at `docs/References/WHATWG/`.

---

## Generic URI grammar — RFC 3986 (STD 66)

We enforce the generic URI grammar at construction time, so a built
`URL` is well-formed by the time it reaches the caller.

| Guarantee | Spec | Test |
|---|---|---|
| Percent-encoding triplets are rendered with uppercase hex | RFC 3986 §2.1, §6.2.2.2 | `RFC3986/§6.2.2.2 — percent-encoding uses uppercase hex digits` |
| Reserved gen-delims and sub-delims preserved where the grammar allows | RFC 3986 §2.2 | `RFC3986/§2.2 — preserves pchar reserved/sub-delims and unreserved in path` |
| Unreserved set passes unencoded | RFC 3986 §2.3 | `RFC3986/§2.3 — passes the full unreserved set unencoded in path` |
| Already-encoded triplets are not double-encoded | RFC 3986 §2.4 | `RFC3986/§2.4 — does not double-encode an existing percent triplet in path` |
| Scheme grammar enforced and normalised to lowercase | RFC 3986 §3.1, §6.2.2.1; RFC 7595 §3.8 | `RFC3986/accepts and lowercases valid schemes`, `RFC3986/rejects schemes that violate the ABNF`, `RFC9110/§4.2.3 — uppercase scheme on input round-trips lowercase on output` |
| Userinfo is disabled by default; username and password fields require explicit `URLBuildConfiguration.userInfoPolicy` opt-in | RFC 3986 §3.2.1; RFC 9110 §4.2.4 | `RFC3986Userinfo/§3.2.1 — userinfo is disabled by default`, `RFC3986Userinfo/§3.2.1 — username-only userinfo is opt-in`, `RFC3986Userinfo/§3.2.1 — password userinfo requires explicit password policy`, `RFC3986Userinfo/§3.2.1 — username/password userinfo is opt-in` |
| Userinfo fields are UTF-8 percent-encoded from raw values and cannot smuggle authority delimiters | RFC 3986 §2.1, §3.2.1 | `RFC3986Userinfo/§3.2.1 — userinfo raw fields are percent-encoded as UTF-8`, `RFC3986Userinfo/§3.2.1 — empty username is rejected`, `RFC3986Userinfo/§3.2.1 — empty password is rendered explicitly` |
| Userinfo requires an authority host, rejects duplicate declarations, and never echoes secret values in errors | RFC 3986 §3.2, §7.5 | `RFC3986Userinfo/§3.2 — userinfo requires an authority host`, `RFC3986Userinfo/§3.2.1 — duplicate userinfo declarations are rejected`, `RFC3986Userinfo/§7.5 — userinfo validation errors do not echo secrets` |
| `@` cannot smuggle userinfo through a host string or composed-host label | RFC 3986 §3.2.1; RFC 9110 §4.2.4 | `Security/rejects at-sign in host string`, `Security/rejects userinfo prefix in host string`, `RFC3986Userinfo/§3.2.1 — composed-host label rejects '@' (security note)` |
| Reg-name hosts are normalised (case, trailing-dot root preserved) | RFC 3986 §3.2.2, §6.2.2.1 | `RFC3986/§6.2.2.1 — lowercases mixed-case host`, `RFC3986/§3.2.2 — preserves absolute DNS root dot` |
| IPv4 / IPv6 / IPvFuture literals follow RFC 3986 §3.2.2 with bracketing for IP-literal | RFC 3986 §3.2.2 | `RFC3986/§3.2.2 — accepts canonical IPv4 literals`, `RFC3986/§3.2.2 — rejects out-of-range and zero-padded IPv4 octets`, `IPv6/RFC 3986 §3.2.2 — accepts pre-bracketed IPv6 literal`, `RFC3986/§3.2.2 — accepts valid IPvFuture literal`, `RFC3986/§3.2.2 — rejects malformed IPvFuture literals` |
| Port grammar `*DIGIT` with the reserved range removed | RFC 3986 §3.2.3; RFC 6335 §6 | `Security/rejects port zero`, `RFC3986Port/§3.2.3 — accepts ports across the valid range`, `RFC3986Port/§3.2.3 — rejects out-of-range ports` |
| Path segment grammar (pchar set) and backslash refusal | RFC 3986 §3.3 | `RFC3986/§2.2 — preserves pchar reserved/sub-delims and unreserved in path`, `RFC3986Path/§3.3 + §5.2.4 — rejects literal dot, dot-dot, slash, backslash, and NUL segments` |
| Empty path with authority renders as `/` when explicitly declared | RFC 3986 §3.3; RFC 9110 §4.2.3 | `RFC9110/§4.2.3 — explicit empty path renders as '/' for http(s)` |
| Absent path remains absent by DSL design, documenting the deliberate RFC 9110 §4.2.3 normal-form deviation | Requirements §10; RFC 9110 §4.2.3 | `RFC9110/§4.2.3 — absent path remains absent by DSL design`, `WHATWGURLDivergence/RFC 9110 §4.2.3 — keeps absent http(s) path absent (vs. WHATWG-style slash)` |
| Literal `.` / `..` segments and percent-encoded variants rejected | RFC 3986 §3.3, §5.2.4; RFC 6943 §3.4 | `URLBuilderTests/rejects traversal path segments`, `RFC3986Path/§3.3 + §5.2.4 — rejects literal dot, dot-dot, slash, backslash, and NUL segments`, `Security/rejects percent-encoded dot segments` |
| Query and fragment grammar preserve allowed characters and percent-encode reserved ones | RFC 3986 §3.4, §3.5 | `RFC3986/§3.4 — preserves '/' and '?' in value, encodes '&' and '='`, `RFC3986/§3.5 — preserves '/' and '?' in fragment` |

## HTTP schemes — RFC 9110

`http` and `https` declarations follow the HTTP semantics document.

| Guarantee | Spec | Test |
|---|---|---|
| `http`/`https` URIs are emitted with the authority prefix | RFC 9110 §4.2.1, §4.2.2 | `RFC9110/§4.2.1 — http URI emits 'http://' authority prefix`, `RFC9110/§4.2.2 — https URI emits 'https://' authority prefix` |
| Default ports omitted (80 for http, 443 for https) | RFC 9110 §4.2.1, §4.2.2 | `RFC9110/§4.2.3 — omits default HTTP and HTTPS ports` |
| Empty path is equivalent to `/`; explicit declaration is preserved | RFC 9110 §4.2.3 | `RFC9110/§4.2.3 — explicit empty path renders as '/' for http(s)` |
| Absent path stays absent as a locked DSL deviation from the RFC normal form | Requirements §10 | `RFC9110/§4.2.3 — absent path remains absent by DSL design`, `WHATWGURLDivergence/RFC 9110 §4.2.3 — keeps absent http(s) path absent (vs. WHATWG-style slash)` |
| Scheme and host are case-insensitive and normalised to lowercase | RFC 9110 §4.2.3 | `RFC9110/§4.2.3 — http(s) host case is normalised to lowercase`, `RFC9110/§4.2.3 — uppercase scheme on input round-trips lowercase on output` |
| Userinfo in `http(s)` URIs is refused by default and only generated under explicit caller policy | RFC 9110 §4.2.4 | `RFC3986Userinfo/§3.2.1 — userinfo is disabled by default`, `RFC3986Userinfo/§3.2.1 — username/password userinfo is opt-in` |
| C0 controls (CR/LF/NUL/...) refused in path/query/fragment, blocking URI-based header injection | RFC 9110 §11.7.6 | `WHATWGURLDivergence/RFC 3986 §2 — rejects ASCII control characters (vs. WHATWG strips them)`, `Security/rejects C0 controls in query name`, `Security/rejects C0 controls in query value`, `Security/rejects C0 controls in fragment` |

## Internationalisation — RFC 3987 + IDNA2008 (RFC 5890–5894)

Non-ASCII input is mapped onto URI bytes through IDNA2008 with strict
codepoint classification.

| Guarantee | Spec | Test |
|---|---|---|
| U-labels are converted to A-labels via Punycode | RFC 5890 §2.3, RFC 5891 §4, RFC 3492 | `IRI/RFC 3987 §3.1 + RFC 5891 §4 — U-label converted to A-label (Punycode)`, `RFC3492Punycode/RFC 3492 — U-label round-trips through known A-label encoding`, `RFC3492Punycode/RFC 3492 — encoding is deterministic for the same input`, `RFC3492Punycode/RFC 5891 §4.5 — pre-encoded A-label is not double-encoded` |
| ACE prefix `xn--` accepted case-insensitively | RFC 5890 §2.3.2.1 | `RFC3492Punycode/RFC 5890 §2.3.2.1 — ACE prefix is case-insensitive on input` |
| Labels are NFC-normalised before classification | RFC 5891 §5.4 | `RFC5892/RFC 5891 §5.4 — NFC normalisation before IDNA processing` |
| ucschar is preserved in path/query and percent-encoded as UTF-8 bytes | RFC 3987 §3.1, RFC 3629 §3 | `IRI/RFC 3987 §3.1 — non-ASCII path segment is percent-encoded via UTF-8`, `IRI/RFC 3987 §3.1 — non-ASCII query value is percent-encoded via UTF-8`, `RFC3629UTF8Encoding/§3 (2-byte) — U+0080..U+07FF encodes to two %HH bytes in path`, `RFC3629UTF8Encoding/§3 (3-byte) — U+0800..U+FFFF encodes to three %HH bytes in query`, `RFC3629UTF8Encoding/§3 (4-byte) — supplementary plane encodes to four %HH bytes in fragment`, `RFC3629UTF8Encoding/§3 — mixed 1/2/3/4-byte sequence preserves byte order`, `RFC3629UTF8Encoding/§6 + RFC 3987 §3.1 — UTF-8 mapping is deterministic` |
| Invalid/overlong UTF-8 percent sequences are not decoded into scalar data | RFC 3629 §4 | `RFC3629UTF8Encoding/§4 — overlong UTF-8 percent sequence is not decoded` |
| A-label normalisation is case-insensitive | RFC 3987 §5.3.2 | `IRI/RFC 5891 §4 — A-label case is normalised to lowercase` |

## IDNA codepoint classification — RFC 5892 (backed by ISO/IEC 10646)

Codepoint classification gates every host label, and we enforce it
ahead of Foundation IDNA so DISALLOWED scalars are rejected outright
rather than silently Punycode-encoded.

| Guarantee | Spec | Test |
|---|---|---|
| PVALID — ASCII letters/digits accepted | RFC 5892 §2.1 | `RFC5892/§2.1 PVALID — ASCII letters and digits accepted unchanged` |
| PVALID — non-ASCII letters become A-labels | RFC 5892 §2.1; RFC 3987 §3.1 | `RFC5892/§2.1 PVALID — non-ASCII letter converts to Punycode A-label` |
| DISALLOWED — emoji and Other_Symbol rejected | RFC 5892 §2.4 | `RFC5892/§2.4 DISALLOWED — emoji symbol rejected in host label` |
| DISALLOWED — currency, math, and modifier symbols rejected | RFC 5892 §2.4 | `RFC5892/§2.4 DISALLOWED — currency symbol rejected in host label`, `RFC5892/§2.4 DISALLOWED — math symbol rejected in host label` |
| DISALLOWED — punctuation rejected | RFC 5892 §2.4 | `RFC5892/§2.4 DISALLOWED — punctuation/symbol rejected in host label` |
| DISALLOWED — non-character codepoints (FDD0..FDEF, *FFFE/*FFFF) rejected | RFC 5892 §2.4 | `RFC5892/§2.4 DISALLOWED — non-character codepoint rejected in host label` |
| DISALLOWED — C0 controls rejected | RFC 5892 §2.4 | `RFC5892/§2.4 DISALLOWED — C0 control codepoint rejected in host label` |
| CONTEXTJ — bare ZWJ / ZWNJ rejected outside their contextual rule | RFC 5892 §2.2 | `RFC5892Context/§2.2 — rejects bare ZWNJ in Latin label (no contextual match)`, `RFC5892Context/§2.2 — rejects bare ZWJ in Latin label (no contextual match)` |
| CONTEXTO — script-specific codepoints rejected outside their script | RFC 5892 §2.3 | `RFC5892Context/§2.3 — rejects CONTEXTO codepoint outside its script context` |

## DNS host names — RFC 1035 + RFC 1123

Hostnames respect DNS preferred-syntax constraints.

| Guarantee | Spec | Test |
|---|---|---|
| Label syntax (LDH; first/last char alphanumeric) | RFC 1035 §2.3.1 | `RFC1035DNSLabels/RFC 1035 §2.3.1 — rejects labels starting or ending with a hyphen`, `RFC1035DNSLabels/RFC 1035 §2.3.1 — accepts interior hyphens in DNS label` |
| Label length 1–63 octets, total host ≤ 253 | RFC 1035 §2.3.4 | `RFC1035DNSLabels/RFC 1035 §2.3.4 — accepts 63-octet maximum-length label`, `RFC1035DNSLabels/RFC 1035 §2.3.4 — rejects 64-octet over-limit label`, `RFC1035DNSLabels/RFC 1035 §2.3.4 — rejects host longer than 253 octets` |
| Digit-leading label allowance | RFC 1123 §2.1 | `RFC1035DNSLabels/RFC 1123 §2.1 — accepts digit-leading DNS label` |
| Single trailing dot (absolute root) preserved | RFC 3986 §3.2.2 | `RFC1035DNSLabels/RFC 3986 §3.2.2 — preserves single trailing dot (absolute root)` |

## IPv6 literals — RFC 4291 + RFC 5952 + RFC 9844

IPv6 input is canonicalised to RFC 5952 form, with zone identifiers
firmly excluded from URI host literals.

| Guarantee | Spec | Test |
|---|---|---|
| Preferred form `x:x:x:x:x:x:x:x` accepted | RFC 4291 §2.2 (1) | `IPv6/RFC 4291 §2.2 (1) — accepts full 8-group preferred form` |
| Compressed form via `::` accepted; only one `::` allowed | RFC 4291 §2.2 (2) | `IPv6/RFC 4291 §2.2 (2) — accepts compressed form '::'`, `IPv6/RFC 4291 §2.2 — rejects multiple '::' substitutions` |
| Canonical form: leading-zero suppression, longest-zero-run collapse, lowercase hex | RFC 5952 §4.1, §4.2.1, §4.3 | `IPv6/RFC 5952 §4.1+§4.2+§4.3 — canonicalizes leading zeros, lowercases, compresses`, `IPv6/RFC 5952 §4.2.2 — '::' compresses the longest zero run` |
| Literal bracketed in URI authority | RFC 5952 §5; RFC 3986 §3.2.2 | `IPv6/RFC 3986 §3.2.2 — accepts pre-bracketed IPv6 literal` |
| Embedded IPv4 forms (`::ffff:a.b.c.d`, `::a.b.c.d`) accepted; out-of-range octets rejected | RFC 4291 §2.5.5; RFC 5952 §5 | `RFC5952EmbeddedIPv4/RFC 5952 §5 — accepts IPv4-mapped IPv6 dotted-quad form`, `RFC5952EmbeddedIPv4/RFC 4291 §2.5.5.1 — accepts IPv4-compatible IPv6 dotted-quad form`, `RFC5952EmbeddedIPv4/RFC 5952 §5 — rejects embedded IPv4 with out-of-range octet` |
| Zone identifiers refused in URI host literals | RFC 9844 §4 (obsoletes RFC 6874) | `RFC9844/RFC 9844 §4 — rejects IPv6 zone identifier in URI host literal` |

## Port — RFC 6335

| Guarantee | Spec | Test |
|---|---|---|
| Port 0 rejected (reserved) | RFC 6335 §6 | `RFC3986Port/RFC 6335 §6 — rejects reserved port 0`, `Security/rejects port zero` |

## Identifier comparison — RFC 6943

| Guarantee | Spec | Test |
|---|---|---|
| Percent-decoded equivalence considered when security depends on it (dot-segment recheck) | RFC 6943 §3.4 | `Security/rejects percent-encoded dot segments` |

## Special-use domain names — RFC 2606 / 6761 / 6762 / 7686 / 8375 / 9476

Reserved names are accepted as well-formed; we never silently rewrite
them.

| Guarantee | Spec | Test |
|---|---|---|
| `.test` / `.example` / `.invalid` / `.localhost` reserved and accepted | RFC 2606 §2 | `SpecialUseTLD/RFC 2606 §2 — accepts reserved TLDs as well-formed hosts` |
| `.local` reserved for mDNS | RFC 6762 §3 | `SpecialUseTLD/RFC 6762 §3 — accepts .local mDNS host as well-formed` |
| `.onion` reserved for Tor | RFC 7686 §2 | `SpecialUseTLD/RFC 7686 §2 — accepts v2-style 16-char .onion host` |
| `home.arpa` reserved for residential networks | RFC 8375 §3 | `SpecialUseTLD/RFC 8375 §3 — accepts .home.arpa multi-label suffix`, `SpecialUseTLD/RFC 8375 — home.arpa is present in the ICANN PSL catalog` |
| `.alt` reserved for non-DNS pseudo-TLDs | RFC 9476 §2 | `SpecialUseTLD/RFC 9476 §2 — accepts .alt pseudo-TLD as well-formed host` |

## Public-suffix catalogue — IANA Root Zone + Mozilla PSL

The catalogue is informational by default; strict mode opts the caller
into rejection of unknown suffixes.

| Guarantee | Source | Test |
|---|---|---|
| Every IANA single-label TLD exposed as a constant on `TopLevelDomain` and via `PublicSuffix.icannTLDs` | IANA Root Zone Database | `IANAPublicSuffixCatalog/IANA — common gTLDs are present in icannTLDs`, `IANAPublicSuffixCatalog/Generated TopLevelDomain constants match the literal string form` |
| Every ICANN public suffix exposed via `PublicSuffix.icannSuffixes` | Mozilla PSL (ICANN section) | `IANAPublicSuffixCatalog/Mozilla PSL — common multi-label suffixes are present in icannSuffixes`, `IANAPublicSuffixCatalog/PublicSuffix.longestMatch — returns longest matching suffix` |
| PSL wildcard parents and exception rules are preserved and applied by `PublicSuffix.contains(_:)` / `longestMatch(for:)` | Mozilla PSL Algorithm 5.1 | `IANAPublicSuffixCatalog/PublicSuffix.contains — applies PSL wildcard and exception semantics`, `IANAPublicSuffixCatalog/PublicSuffix.longestMatch — exceptions prevail over wildcard rules` |
| Multi-label suffixes compose at the call site (`TLD.co.uk`, `TLD.com.au`, …) and equal their literal form | derived API | `TLDChainComposition/Two-label chain joins with '.'`, `TLDChainComposition/Chain extends an existing static TLD constant`, `TLDChainComposition/Three-label chains compose left-to-right`, `TLDChainComposition/Chain value equals the literal-string form`, `TLDChainComposition/Chain values hash consistently with literal-string form`, `TLDChainComposition/HTTPS(domain, TLD) accepts a chain value`, `TLDChainComposition/HTTP(domain, TLD) accepts a chain value`, `TLDChainComposition/Host builder domain and tld accepts a chain value`, `TLDChainComposition/Host result builder accepts a TLD chain value`, `TLDChainComposition/TopLevelDomain component accepts a chain value`, `TLDChainComposition/TLD component accepts a chain value` |
| Strict mode rejects composed `tld(...)` and host strings that don't match the catalogue; IPv4 and IPv6 literals exempt | Requirements §10.3 | `PublicSuffixEnforcement/Strict mode rejects unknown single-label TLDs`, `PublicSuffixEnforcement/Strict mode rejects unknown multi-label suffix chains`, `PublicSuffixEnforcement/Strict mode rejects host strings whose last label is not a TLD`, `PublicSuffixEnforcement/Strict mode accepts known single-label TLDs`, `PublicSuffixEnforcement/Strict mode accepts known multi-label suffixes via the chain`, `PublicSuffixEnforcement/Strict mode accepts IPv4 literal hosts (TLD enforcement is name-only)`, `PublicSuffixEnforcement/Strict mode accepts IPv6 literal hosts (TLD enforcement is name-only)` |
| Default permissive behaviour preserved (Requirements §10.3) | locked decision | `PublicSuffixEnforcement/Default configuration accepts unknown TLDs in composed hosts`, `PublicSuffixEnforcement/Default configuration accepts unknown TLDs in host strings` |

## Query encoding modes — `URLBuildConfiguration.queryEncoding`

The default produces URI-grammar query items; an opt-in mode produces
`application/x-www-form-urlencoded` rendering for callers who need
HTML-form parity.

| Mode | Guarantee | Spec | Test |
|---|---|---|---|
| `.rfc3986` (default) | SPACE renders as `%20`; literal `+` preserved | RFC 3986 §2.1 | `QueryEncodingMode/RFC 3986 §2.1 (default) — SPACE renders as %20 in query value`, `QueryEncodingMode/RFC 3986 §2.1 (default) — SPACE renders as %20 in query name`, `QueryEncodingMode/RFC 3986 §2.1 (default) — literal '+' is preserved as a sub-delim` |
| `.formURLEncoded` | SPACE renders as `+`; literal `+` renders as `%2B` | WHATWG URL §5.2 | `QueryEncodingMode/WHATWG URL §5.2 (.formURLEncoded) — SPACE renders as '+' in query value`, `QueryEncodingMode/WHATWG URL §5.2 (.formURLEncoded) — SPACE renders as '+' in query name`, `QueryEncodingMode/WHATWG URL §5.2 (.formURLEncoded) — literal '+' is encoded as %2B` |
| `.formURLEncoded` | Reserved chars (`= & ? # / : @ ! $ ' ( ) , ; ~`) percent-encoded | WHATWG URL §5.2 | `QueryEncodingMode/WHATWG URL §5.2 (.formURLEncoded) — sub-delims and reserved chars are percent-encoded` |
| `.formURLEncoded` | Non-ASCII encoded from UTF-8 bytes | RFC 3629 §3 | `QueryEncodingMode/RFC 3629 §3 + WHATWG URL §5.2 — non-ASCII is encoded from its UTF-8 byte sequence` |
| `.formURLEncoded` | Unreserved bytes (alphanumerics + `* - . _`) preserved | WHATWG URL §5.2 | `QueryEncodingMode/WHATWG URL §5.2 (.formURLEncoded) — pass-through bytes are unencoded` |
| Both modes | Validation parity (CR/LF, NUL, empty-name rejection) | RFC 9110 §11.7.6 | `QueryEncodingMode/.formURLEncoded preserves CR/LF rejection in query name`, `QueryEncodingMode/.formURLEncoded preserves NUL rejection in query value`, `QueryEncodingMode/.formURLEncoded preserves empty-name rejection` |

## Query deduplication — `URLBuildConfiguration.queryDeduplication`

Repeated query keys are valid URI syntax and remain the default output.
Deduplication is opt-in for call sites that need map-like query
semantics.

| Guarantee | Source | Test |
|---|---|---|
| Default policy preserves every repeated key in declaration order | RFC 3986 §3.4; WHATWG URL §5.1 | `QueryDeduplication/.none preserves repeated keys in declaration order`, `QueryDeduplication/.none is the default policy` |
| `.lastWins` keeps one entry per key, using the last value at the first occurrence's rendered position | WHATWG URL §6.2 placement semantics | `QueryDeduplication/.lastWins keeps the last value at the first occurrence's position`, `QueryDeduplication/.lastWins overrides interleaved keys at their first positions`, `QueryDeduplication/.lastWins on a single duplicate key collapses to one entry`, `QueryDeduplication/.lastWins replaces a flag with a later value declaration` |
| `.firstWins` keeps one entry per key, using the first value at the first occurrence's rendered position | derived API | `QueryDeduplication/.firstWins keeps the first value and drops later occurrences`, `QueryDeduplication/.firstWins preserves the first value across interleaved keys`, `QueryDeduplication/.firstWins on a single duplicate key collapses to one entry`, `QueryDeduplication/.firstWins keeps a flag declared first` |
| Deduplication composes with other query options and leaves unrelated URLs unchanged | derived API | `QueryDeduplication/single-occurrence keys are unchanged across policies`, `QueryDeduplication/dedup policies leave a query-less URL unchanged`, `QueryDeduplication/.lastWins composes with formURLEncoded query encoding`, `QueryDeduplication/queryDeduplication modifier returns a configuration with the requested policy` |

## DSL and macro surface — derived API

The macro APIs do not change URI validation; they forward to or
synthesize the same builder declarations covered above.

| Guarantee | Source | Test |
|---|---|---|
| `#URL` forwards to `URLBuilder`, including explicit configuration | Swift macro expansion | `URLBuilderMacros/#URL forwards a trailing closure to URLBuilder`, `URLBuilderMacros/#URL forwards a configuration argument and trailing closure`, `MacroIntegration/#URL expands and produces the same URL as URLBuilder`, `MacroIntegration/#URL forwards an explicit configuration` |
| `#URL` works in expression-only contexts such as property getters | Swift freestanding expression macro | `MacroIntegration/#URL works as a property getter expression` |
| `@URLQuery` synthesizes `URLQueryRepresentable` for scalar, optional, array, and combined DTO properties | Swift attached extension macro | `URLQueryMacro/@URLQuery synthesizes scalar property as Query call`, `URLQueryMacro/@URLQuery emits if-let for optional property`, `URLQueryMacro/@URLQuery emits for-loop for array property`, `URLQueryMacro/@URLQuery composes scalar, optional, array, flag, ignore, custom key`, `URLQueryMacroIntegration/@URLQuery composes all features at runtime` |
| `@Query` customizes synthesized query output and rejects malformed attributes | Swift attached peer macro | `URLQueryMacro/@Query(.key) overrides the rendered key`, `URLQueryMacro/@Query(.flag) renders Bool as flag with property name`, `URLQueryMacro/@Query(.ignore) excludes a property from synthesis`, `URLQueryMacroIntegration/@Query(.key) renders the override at runtime`, `URLQueryMacroIntegration/@Query(.flag) renders true Bool as a flag`, `URLQueryMacroIntegration/@Query(.ignore) excludes the property at runtime`, `QueryAttributeMacro/@Query with a malformed argument is rejected with a diagnostic` |

## Conscious deviations from the WHATWG URL Standard

We treat WHATWG as a divergence baseline rather than a target. Each
deviation we know about is pinned by a test so a future regression
surfaces immediately.

| Behaviour | DSL choice | Test |
|---|---|---|
| Backslash-in-path normalisation | Refused (RFC 3986 pchar excludes `\`) | `WHATWGURLDivergence/RFC 3986 §3.3 — rejects backslash in path segment (vs. WHATWG normalises)` |
| Tab/CR/LF stripping | Refused (RFC 9110 §11.7.6) | `WHATWGURLDivergence/RFC 3986 §2 — rejects ASCII control characters (vs. WHATWG strips them)` |
| `application/x-www-form-urlencoded` SPACE→`+` in default mode | RFC 3986 §2.1: SPACE→`%20` (opt-in via `.formURLEncoded`) | `WHATWGURLDivergence/RFC 3986 §2.1 — encodes SPACE as %20 in query (vs. WHATWG '+')` |
| Lone-surrogate U+FFFD substitution | Refused (RFC 5892 §2.4) | `WHATWGURLDivergence/RFC 5892 §2.4 — rejects U+FFFD substitution in host` |

## ISO/IEC 10646 (UCS) — indirect coverage

ISO/IEC 10646 is in scope only because it is the codepoint repertoire
on which RFC 3987 and RFC 5892 are defined. We exercise it through
the Unicode Character Database properties surfaced by Swift's
`Unicode.Scalar`.

| Aspect | Where exercised | Local source |
|---|---|---|
| Codepoint repertoire (PVALID/DISALLOWED/CONTEXTJ/CONTEXTO) | `RFC5892_IDNAClassification.swift`, `RFC5892_CONTEXT.swift` | `ISO-IEC/iso-iec-10646-2020-FCD-unicode.org.pdf`, `ISO-IEC/UnicodeData.txt`, `ISO-IEC/DerivedCoreProperties.txt` |
| UTF-8 encoding form (1/2/3/4-byte sequences) | `RFC3629_UTF8Encoding.swift` | `RFCs/rfc3629.txt` |
| Compatibility processing notes (UTS#46 vs strict RFC 5891) | documented in `References/INDEX.md` | `ISO-IEC/unicode-tr46-idna-compatibility-processing.html`, `ISO-IEC/IdnaMappingTable.txt` |

## Standards explicitly out of scope

| Standard | Why it does not bind URLBuilder |
|---|---|
| ISO 3166-1 alpha-2 | Country-code candidate set; ICANN's ccTLD Delegation Policy is the operational authority for root-zone delegation. The IANA Root Zone is what `PublicSuffix.icannTLDs` reflects. |
| ISO 639-1/2/3 | Language tags (BCP 47) belong in HTTP `Accept-Language`, not URI structure. |
| ISO/IEC 14651 | Collation problem; URL construction does not collate. |
| ISO/IEC 8859-1 | Pre-RFC 3986 legacy. RFC 3986 §2.5 + RFC 3987 §3.1 mandate UTF-8 (RFC 3629). |
| ISO/IEC 27001 / 27002 | ISMS process standard, not output constraint. |
| ISO/IEC 9075 (SQL), ISO/IEC 80000-13 | Unrelated subject matter. |
| RFC 9111 / 9112 | Non-URL parts of HTTP. |
| RFC 5234 / 7405 | ABNF notation specifications; URLBuilder follows the ABNF in RFC 3986/3987 but these RFCs add no producer behaviour. |
| RFC 7320 / 8820 | URI design and ownership guidance; useful background for API design, not emitted-URL compliance targets. |
| RFC 1738 / 2732 / 3490 | Fully obsoleted predecessors. |
| RFC 7230–7235 | Obsoleted by RFC 9110/9111/9112. |
| RFC 6454 (Origin), RFC 6265 (Cookies) | Derived from a parsed URL or applied to a cookie jar; not URI-construction concerns. |

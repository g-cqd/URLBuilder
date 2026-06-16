# Security

The validation guarantees URLBuilder makes, and the threat model behind them.

## Overview

URLBuilder treats caller-provided component text as untrusted and validates it against an
allowlist before composing a URL. The goal is to make whole classes of URL-injection and
spoofing bugs unrepresentable, rather than relying on downstream encoding.

## What is rejected

- **Path traversal.** `.` and `..` segments are rejected, as are their percent-encoded forms
  (`%2e`, `%2E`, `%2e%2e`), so traversal cannot be smuggled past the dot-segment guard. Segments
  containing `/` or `\` are rejected.
- **Control & bidi characters.** C0/C1 controls, `DEL`, line/paragraph separators, and bidi
  formatting overrides (LRM/RLM/LRE/RLE/PDF/LRO/RLO) are rejected in path, query, and fragment
  text (RFC 3986 §2, RFC 3987 §4.1, RFC 9110 §11.7.6) — closing CRLF/header-injection and
  visual-spoofing vectors.
- **Host delimiters.** `/`, `\`, `?`, `#`, `@`, `:`, brackets, and surrounding whitespace are
  rejected in registered names, so a host cannot carry an embedded authority or path.
- **IDNA DISALLOWED scalars.** Unicode hosts are screened against RFC 5892 §2.4 before Foundation's
  IDNA pass (see <doc:HostsAndIDNA>), because Foundation would otherwise Punycode some disallowed
  codepoints instead of rejecting them.
- **Userinfo.** Disabled by default; even when enabled, subcomponents are percent-encoded to a
  strict unreserved set and forbidden scalars are rejected.

## Why the `URL(string:)` re-parse is safe

Host validation re-parses through `URL(string: "https://\(host)")` to leverage Foundation's
normalization. This is safe because the delimiters, `:`/brackets, and control characters that
could change the parse are rejected *before* the re-parse — there is nothing left that could move
the authority/path boundary.

## Fail-closed posture

Where a platform capability is missing — for example, IPv6 literal validation on a platform with
no POSIX `inet_pton`/`inet_ntop` — the affected input is **rejected**, never accepted unvalidated.

## Typed, exhaustive errors

Every rejection is a case of ``URLBuildError``, a closed enum, surfaced through Swift typed throws
from `withThrowingURL`. Callers handle each failure explicitly; nothing is swallowed. (The
trapping `URLBuilder { … }` entry point is reserved for static literals you control.)

## Determinism

Query rendering is deterministic: `Encodable` values use sorted JSON keys, and `@URLQuery` sorts
`Set` iteration (see <doc:QueriesAndEncoding>). Stable output matters for HMAC URL signing, cache
keys, and snapshot tests.

## Topics

### Errors

- ``URLBuildError``

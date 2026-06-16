# Hosts and IDNA

How URLBuilder validates registered-name hosts, Unicode (IDNA) labels, and IP literals.

## Overview

A host reaches a URL through one of three shapes: a registered name (DNS-style), an IPv6/IP
literal, or a composed host built from typed labels. Each is validated before it is handed to
Foundation `URLComponents`.

## Registered names

``Host`` accepts a complete name (`Host("api.apple.com")`) or a composition of ``Subdomain``,
``Domain``, and ``TopLevelDomain`` declarations. Validation enforces:

- per-label length ≤ 63 octets and total host ≤ 253 octets (RFC 1035);
- labels limited to ASCII letters, digits, and `HYPHEN-MINUS`, not beginning or ending with `-`;
- no host delimiters (`/`, `\`, `?`, `#`, `@`), no `:` or brackets, and no surrounding whitespace;
- rejection of invalid IPv4 literals (out-of-range octets, leading zeros).

A registered name that is re-parsed through `URL(string:)` is safe precisely because these
delimiters and control characters are rejected *first*.

## Unicode labels (IDNA)

Unicode hosts are screened for RFC 5892 **DISALLOWED** scalars *before* Foundation's IDNA pass.
This is deliberate: Foundation's IDNA implementation Punycode-encodes some DISALLOWED codepoints
(emoji and other symbols, punctuation, separators, non-characters, controls, surrogates,
private-use, unassigned) instead of rejecting them. URLBuilder rejects them up front:

```swift
try withThrowingURL { HTTPS { Host("bücher.example") } }   // ok → xn--bcher-kva.example
try withThrowingURL { HTTPS { Host("exa🅰mple.com") } }     // throws .invalidHost
```

The classification is backed by Unicode general categories and the Noncharacter_Code_Point
property; ASCII (< 0x80) is handled by the registered-name rules above.

## IP literals

- ``Host/ipv6(_:)`` validates an IPv6 address through the platform C library
  (`inet_pton`/`inet_ntop`) and re-emits it in canonical, bracketed form. Brackets are optional in
  the argument.
- ``IPLiteral`` / ``Host/ipLiteral(_:)`` accepts an IPv6 literal or an RFC 3986 IPvFuture literal.
- ``IPvFuture`` / ``Host/ipvFuture(_:)`` declares an IPvFuture literal (`v<hex>.<address>`).

> Important: IPv6 validation requires a POSIX `inet_pton`/`inet_ntop` (Darwin or Glibc). On a
> platform without them, IPv6 literals **fail closed** (they are rejected) rather than being
> accepted unvalidated.

## Topics

### Host declarations

- ``Host``
- ``Subdomain``
- ``Domain``
- ``TopLevelDomain``
- ``IPLiteral``
- ``IPvFuture``

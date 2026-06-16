# Public Suffixes

How URLBuilder enforces registrable domains under a known public suffix, and how the suffix list
is generated.

## Overview

A *public suffix* is a label under which the public can register names (`com`, `co.uk`,
`aichi.nagoya`). Enforcing that a host ends with a known public suffix — and has a registrable
label below it — rejects typos and certain spoofing shapes before a request is ever made.

Enforcement is **opt-in** through ``URLBuildConfiguration`` and
``URLBuildConfiguration/TLDEnforcement``:

```swift
// Permissive (default): any well-formed host is accepted.
let a = try withThrowingURL { HTTPS { Host("example.test") } }

// Strict: the host must end with a known public suffix.
let config = URLBuildConfiguration.default        // configure .strict enforcement here
let b = try withThrowingURL(configuration: config) {
    HTTPS { Subdomain("www"); Domain("apple"); TLD.com }
}
```

Under `.strict`, a composed ``TopLevelDomain`` is checked against the embedded list, and a literal
host is required to have a longest-match public suffix with at least one registrable label below
it. IPv4 literals are exempt; IPv6 literals never reach this path.

## Multi-label suffixes

Single-label suffixes are values (`TLD.com`, `TLD.org`). Multi-label suffixes use the
dynamic-member chain, which is *not* validated at the call site — strict enforcement at build time
is what rejects an unknown chain:

```swift
TLD.co.uk          // TopLevelDomain("co.uk")
TLD.com.au         // TopLevelDomain("com.au")
TLD.aichi.nagoya   // TopLevelDomain("aichi.nagoya")
```

## How matching works

Matching walks the host's labels from the right, longest-match first, against the embedded list.
The match is **iterative**, not recursive, so a pathological host cannot blow the stack.

## How the list is generated

`Sources/URLBuilder/PublicSuffix.swift` is produced at build time by the
`PublicSuffixGeneratorPlugin` from two vendored inputs under `Documentation/References/TLDs/`:

- the IANA Root Zone Database (`tlds-alpha-by-domain.txt`), and
- the Mozilla Public Suffix List (`public_suffix_list.dat`).

Generation is **deterministic**: regenerating from the same inputs yields a byte-identical file,
and CI fails if a regenerated file differs from what is committed. To refresh the list, update the
vendored inputs and rebuild; never hand-edit the generated file.

## Topics

### Enforcement

- ``TopLevelDomain``
- ``URLBuildConfiguration``

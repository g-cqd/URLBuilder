# Working in `URLBuilder`

Type-safe Swift 6 result-builder DSL for RFC-validated URL construction (`g-cqd/URLBuilder`).

## Engineering principles

- **Standards traceability.** Every validation rule corresponds to an explicit RFC / WHATWG / IDNA clause documented in `docs/Standards.md`.
- **Strictness.** Swift 6 language mode, strict concurrency, warnings as errors; keep public targets free of unsafe compiler flags so version-pinned consumption works.
- **Testing & DocC.** Cover every edge case and host/encoding boundary with Swift Testing; keep DocC articles under `Sources/URLBuilder/URLBuilder.docc/` in sync with the API.

## Commands

```sh
swift test
URLBUILDER_DEV=1 swift format lint --strict --recursive Sources Tests Package.swift
```

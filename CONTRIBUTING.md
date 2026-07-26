# Contributing to URLBuilder

Developer tooling lives in the package itself — SwiftPM plugins and committed git hooks — so
there are no shell scripts to run and nothing to install globally.

## One-time setup

Enable the repo's git hooks (pre-commit lint, pre-push test):

```sh
git config core.hooksPath .githooks
```

That's it. The toolchain's bundled `swift format` powers the plugins; no extra tools needed.

**Benchmarks only:** the ordo-one `package-benchmark` dependency (pulled into the `URLBUILDER_DEV=1`
graph) needs the system **jemalloc** headers — `brew install jemalloc` on macOS (`libjemalloc-dev`
on Linux). Without it, `URLBUILDER_DEV=1 swift …` fails at dependency-scan time. Plain `swift build` /
`swift test` don't need it.

## Everyday commands

```sh
swift build                 # build the library
swift test                  # run the test + RFC-conformance suite

swift package format        # format in place  (add --allow-writing-to-package-directory if prompted)
swift package lint          # formatting gate + shipped-library discipline (what CI runs)
```

`swift package lint` is the single source of truth for the lint rules: `swift format lint
--strict`, plus the shipped-library discipline in `Sources/URLBuilder` (no force-unwrap /
force-try / force-cast, and no planning artifacts — `TODO`/`FIXME`/`Phase N`/`[Pn]` — or stray
`print(`). Fix formatting with `swift package format`. A single reviewed exception can be annotated
with a trailing `// lint:allow` comment.

## The public-suffix generator

`Sources/URLBuilder/PublicSuffix.swift` is **generated** at build time by the
`PublicSuffixGeneratorPlugin` from the vendored IANA Root Zone Database and Mozilla Public Suffix
List under `docs/References/TLDs/`. Never edit the generated file by hand — change the
generator (`Sources/PublicSuffixGeneratorCore`) or the vendored inputs instead.

The generation is deterministic: regenerating from the same inputs must produce a byte-identical
file. CI enforces this (`generator-reproducibility`); to reproduce locally, run the generator over
the vendored inputs and confirm `git diff --exit-code` is clean.

## Sanitizers

`--sanitize` instruments the whole graph (no manifest change needed). TSan and ASan are
**mutually exclusive**, so run them as separate passes:

```sh
swift test --sanitize=thread                        # data races
swift test --sanitize=address --sanitize=undefined  # OOB / use-after-free in the IPv6 C interop
```

The IPv6 literal path calls the platform C library (`inet_pton`/`inet_ntop`), so the ASan/UBSan
pass is the one that exercises that boundary; `-enable-actor-data-race-checks` (already on for the
test target) only covers actor isolation.

## The `URLBUILDER_DEV` flag

Heavier dev tooling is gated behind the `URLBUILDER_DEV` environment variable so that packages
which merely *depend on* URLBuilder never resolve it. Set it when you want:

```sh
# Build-time formatting enforcement (the LintBuild plugin attaches to the URLBuilder target):
URLBUILDER_DEV=1 swift build      # fails the build on any formatting violation

# Generate the DocC documentation (pulls swift-docc-plugin):
URLBUILDER_DEV=1 swift package generate-documentation --target URLBuilder
```

The `format` and `lint` command plugins are dependency-free and work without the flag.

## Dependencies & `Package.resolved`

The shipped graph is intentionally small: **swift-syntax** (the `@URLQuery` / `#URL` macros need
it) and **ADJSON** (the JSON encoding path for `Encodable` query values). swift-docc-plugin is
gated behind `URLBUILDER_DEV` so consumers never resolve it.

`Package.resolved` is **gitignored** (the library convention — an application pins exact versions,
a library lets its consumers' resolution win).

> **Note:** while ADJSON is pinned to its `main` branch (it has not yet tagged a release), a
> *tagged* URLBuilder release cannot itself be resolved through `.package(url:from:)` — SwiftPM
> forbids a versioned package from depending on an unversioned one. Switch the ADJSON requirement
> to a `from:` tag before publishing a versioned URLBuilder release.

### Developing against ADJSON

ADJSON always resolves from the published `main` branch — there is no local-checkout override. To
iterate on URLBuilder and ADJSON together, push the ADJSON change and re-resolve
(`swift package update ADJSON`).

## Git hooks

Committed in `.githooks/` and enabled via `core.hooksPath` (above):

- **pre-commit** → `swift package lint` (check-only; blocks the commit on violations).
- **pre-push** → `swift test`.

## CI & documentation

A single workflow — **`.github/workflows/ci.yml`** — chains everything and only fans out after the
gate passes:

- **`build-test`** (macOS): lint → build → test (with code coverage), in one job (one cache).
- **`linux`**: build + test on a Swift Linux container (advisory).
- **`api-stability`**: `swift package diagnose-api-breaking-changes` on PRs.
- **`platforms`**: a cross-platform compile matrix (iOS / tvOS / watchOS / visionOS).
- **`generator-reproducibility`**: regenerates `PublicSuffix.swift` and asserts no diff.
- **`downstream-resolvability`**: a throwaway consumer depends on this repo *by URL* and runs
  `swift package resolve`, locking the no-unsafe-flags invariant that keeps URLBuilder consumable
  as a versioned dependency.
- **`docs`**: builds the DocC site and deploys it to GitHub Pages on `main`. Requires Pages
  source = "GitHub Actions" in the repo settings (a one-time manual step).

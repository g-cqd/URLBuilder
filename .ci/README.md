# CI

`.github/workflows/ci.yml` calls the family's pinned swift-ci workflow, configured by `action.json`, next to this
package's own jobs; run the same checks locally with `.ci/swift-ci local` (the pre-commit hook runs
`.ci/swift-ci run quality`).

Each change runs quality (swift-format, SwiftLint metrics, the shipped-library discipline over
`Sources/URLBuilder`, deadwood, dolly and arcleak against `baselines/`), the Linux debug, release and
AddressSanitizer tests, the flag-free consumer build, and the macOS debug tests with coverage. Release and the
macOS sanitizers run nightly (when a commit landed) or manually. Before swift-ci, the shared workflow ran the macOS
AddressSanitizer and ThreadSanitizer on every change: AddressSanitizer now runs on Linux per change, and the
library's one unsafe boundary keeps its own job.

This package's jobs: the public-API check (pull requests), the Apple-platform builds (main and manual), the
public-suffix generator's reproducibility, a downstream package resolving URLBuilder by URL, macOS address and
undefined-behaviour sanitizers (main, manual, and pull requests that touch the IPv6 validator), and the DocC site
— built on every run, deployed to GitHub Pages from main only. (Warnings are not yet errors: promote it once a
build with `--warnings-as-errors` is shown clean.)

`baselines/` accepts the findings that predate the gate: dolly's 15 warnings (re-recorded by dolly 0.14.3; the
other 85 entries are test-code notes, which never fail) and one deadwood finding, which used to be report-only.
Accept a reviewed false positive where it is (`// @dw:accept -- why`) rather than in the baseline.

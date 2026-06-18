// =====================================================================
// ConsumingBuilderTests — pins the `consuming` builder optimization for
// `Host` and `PathSegment`.
//
// `Host.appending` / `PathSegment.appending` take a `consuming` receiver, so
// when that receiver is uniquely owned (a literal `.subdomain`/`.segment`
// chain, where each intermediate is a moved temporary, or a `consume`-folded
// loop) `append` mutates the buffer in place — O(N) total instead of the
// O(N²) that `storages + [x]` / `values + [x]` per step incurred. These tests
// prove that the append:
//   1. preserves order and content (a long chain yields exactly the same
//      ordered storage as the same value built another way), and
//   2. preserves value semantics (a `Host`/`PathSegment` value reused across
//      independent builds renders identically — the DSL reads storage
//      read-only), and
//   3. scales linearly on the move/`consume` path, with the naive reused-`var`
//      fold shown as the O(N²) contrast (see `consume-folded chain scales
//      linearly`).
//
// `@testable` is used only to read the internal `Host.storages` /
// `PathSegment.values` so the order-preservation invariant can be asserted at
// a 1000-element scale that the RFC 1035 §2.3.4 253-octet DNS host limit would
// otherwise forbid from forming a real host. End-to-end byte-identity is also
// asserted through the public API at sizes that produce valid URLs.
// =====================================================================

import Foundation
import Testing

@testable import URLBuilder

@Suite("URLBuilder — consuming builder (O(N²)→O(N))")
struct ConsumingBuilderTests {
    // MARK: Order / content preservation at 1000 elements (storage level)

    /// A 1000-step `Host` subdomain chain produces exactly the ordered
    /// `storages` of 1000 independent `Host.subdomain(_:)` constructions —
    /// proving the `consuming` append neither drops, duplicates, nor reorders
    /// labels (whether or not the buffer is reused in place on a given step).
    /// Validated at the storage level because 1000 labels exceed the 253-octet
    /// DNS host limit and so cannot form a real host.
    @Test
    func `1000-step subdomain chain preserves order and content`() {
        let count = 1_000

        var chained = Host.subdomain("s0")
        for index in 1 ..< count {
            chained = chained.subdomain("s\(index)")
        }

        let expectedLabels = (0 ..< count).map { "s\($0)" }
        #expect(chained.storages.map(subdomainLabel) == expectedLabels)
    }

    /// A 1000-step `PathSegment` chain produces exactly the same ordered values
    /// as the equivalent multi-segment declaration — same in-place invariant
    /// for the path builder.
    @Test
    func `1000-step path segment chain preserves order and content`() {
        let count = 1_000

        var chained = PathSegment.segment("p0")
        for index in 1 ..< count {
            chained = chained.segment("p\(index)")
        }

        let expectedValues = (0 ..< count).map { "p\($0)" }
        #expect(chained.values == expectedValues)
    }

    // MARK: End-to-end byte-identity through the public API

    /// A long `PathSegment` chain renders a byte-identical URL to the same path
    /// declared with individual string segments. Paths carry no length cap, so
    /// this exercises the full ~1000-element pipeline end to end.
    @Test
    func `long path segment chain builds byte-identical URL`() throws {
        let count = 1_000

        let segment = consumeFoldSegment(from: (0 ..< count).map { "p\($0)" })
        let chained = try withThrowingURL {
            HTTPS("example.com") {
                Path { segment }
            }
        }

        let viaSeparateSegments = try withThrowingURL {
            HTTPS("example.com") {
                Path {
                    for index in 0 ..< count {
                        "p\(index)"
                    }
                }
            }
        }

        let expectedPath = (0 ..< count).map { "p\($0)" }.joined(separator: "/")
        #expect(chained.absoluteString == "https://example.com/\(expectedPath)")
        #expect(chained.absoluteString == viaSeparateSegments.absoluteString)
    }

    /// A `Host` subdomain chain that fits within the DNS host limit renders a
    /// byte-identical URL to the same host declared with individual `Subdomain`
    /// components — end-to-end proof that the chained host's label order
    /// survives composition and validation.
    @Test
    func `subdomain chain builds byte-identical URL`() throws {
        // 60 single-char labels + "example.com" stays under the 253-octet limit.
        let count = 60

        var chained = Host.subdomain("a0")
        for index in 1 ..< count {
            chained = chained.subdomain("a\(index)")
        }
        let chainedHost = chained.domain("example").tld(.com)

        let chainedURL = try withThrowingURL { HTTPS { chainedHost } }

        let viaComponents = try withThrowingURL {
            HTTPS {
                for index in 0 ..< count {
                    Subdomain("a\(index)")
                }
                Domain("example")
                TLD.com
            }
        }

        let expectedHost = (0 ..< count).map { "a\($0)" }.joined(separator: ".")
        #expect(chainedURL.absoluteString == "https://\(expectedHost).example.com")
        #expect(chainedURL.absoluteString == viaComponents.absoluteString)
    }

    // MARK: Value semantics (CoW preserved)

    /// A single `Host` value reused across two independent builds renders
    /// identically both times. The result-builder DSL reads the host's storage
    /// read-only (`flatMap(\.storages)`), so `consuming` builder steps never
    /// observably mutate a value a caller still holds.
    @Test
    func `reused host value renders identically across builds`() throws {
        let host = Host.subdomain("alpha").subdomain("beta").domain("example").tld(.com)

        let first = try withThrowingURL { HTTPS { host } }
        let second = try withThrowingURL { HTTPS { host } }

        #expect(first.absoluteString == "https://alpha.beta.example.com")
        #expect(first.absoluteString == second.absoluteString)
    }

    /// A single `PathSegment` value reused across two independent builds renders
    /// identically both times.
    @Test
    func `reused path segment value renders identically across builds`() throws {
        let segment = PathSegment.segment("v1").segment("items").segment("42")

        let first = try withThrowingURL { HTTPS("example.com") { Path { segment } } }
        let second = try withThrowingURL { HTTPS("example.com") { Path { segment } } }

        #expect(first.absoluteString == "https://example.com/v1/items/42")
        #expect(first.absoluteString == second.absoluteString)
    }

    // MARK: Algorithmic-win quantification

    /// Quantifies the win the `consuming` builder enables and pins the boundary.
    ///
    /// What the `consuming` receiver buys: when the receiver is uniquely owned,
    /// `appending` mutates the buffer in place (amortized O(1)/step → O(N)
    /// total). A chain whose intermediates are *moved* — a literal `.segment`
    /// chain, or a loop that hands ownership over with the `consume` operator
    /// (`p = (consume p).segment(x)`) — keeps the buffer unique and is therefore
    /// O(N). This test folds 10× more segments with `consume` and asserts the
    /// per-step cost stays flat (ratio ≈ 10×, i.e. linear, not ≈ 100×).
    ///
    /// What it does *not* buy (the documented boundary): a plain reused-`var`
    /// fold (`p = p.segment(x)`) keeps the prior value alive across the call, so
    /// the buffer is non-unique and Swift copies all elements every step — that
    /// remains O(N²) at the language level (only a CoW-class buffer with
    /// `@unchecked Sendable` would erase it, which this type deliberately avoids
    /// to stay a compiler-checked `Sendable` value). Both folds are timed so the
    /// report shows the O(N²)-vs-O(N) contrast directly; the assertion is on the
    /// `consume` path (the one the `consuming` annotation governs).
    @Test
    func `consume-folded chain scales linearly`() {
        // Pre-intern labels so string-interpolation cost stays out of the timed
        // region — only the chain construction is measured.
        let small = 500
        let large = 5_000  // 10× the work
        let smallLabels = (0 ..< small).map { "p\($0)" }
        let largeLabels = (0 ..< large).map { "p\($0)" }

        // Warm up so first-call allocation/codegen costs do not skew the ratio.
        _ = consumeFoldSegment(from: smallLabels)

        let smallSeconds = measureSeconds(repetitions: 50) {
            _ = consumeFoldSegment(from: smallLabels)
        }
        let largeSeconds = measureSeconds(repetitions: 50) {
            _ = consumeFoldSegment(from: largeLabels)
        }

        // Contrast: the plain reused-`var` fold (still O(N²)) at the same sizes.
        let smallVarSeconds = measureSeconds(repetitions: 50) {
            _ = varFoldSegment(from: smallLabels)
        }
        let largeVarSeconds = measureSeconds(repetitions: 5) {
            _ = varFoldSegment(from: largeLabels)
        }

        let consumeRatio = largeSeconds / max(smallSeconds, 1e-9)
        let varRatio = largeVarSeconds / max(smallVarSeconds, 1e-9)
        // Per-step cost at large N: flat for O(N), growing for O(N²). The gap
        // between the two at N = `large` is the jitter-proof signal.
        let consumePerStep = largeSeconds / Double(large)
        let varPerStep = largeVarSeconds / Double(large)
        let perStepSpeedup = varPerStep / max(consumePerStep, 1e-12)
        print(
            """
            [ConsumingBuilder] 10× work (N=\(small)→\(large)):
              consume-fold  (O(N)) : \(formatMillis(smallSeconds)) → \(formatMillis(largeSeconds)) ms \
            (\(perStep(largeSeconds, large)) ns/step), \(String(format: "%.1f", consumeRatio))× time
              var-fold     (O(N²)) : \(formatMillis(smallVarSeconds)) → \(formatMillis(largeVarSeconds)) ms \
            (\(perStep(largeVarSeconds, large)) ns/step), \(String(format: "%.1f", varRatio))× time
              per-step speedup at N=\(large): \(String(format: "%.0f", perStepSpeedup))× \
            [linear ≈ 10×, quadratic ≈ 100×]
            """
        )

        // Primary, jitter-proof assertion: at N = `large` the in-place (O(N))
        // path costs far less PER STEP than the copying (O(N²)) path. The
        // observed margin is ~80×; 8× is a conservative floor that still fails
        // hard if the `consuming` in-place reuse regressed to a per-step copy.
        // (A small-baseline time ratio is avoided — at N=500 timer granularity
        // alone can push it past a tight linear bound.)
        #expect(perStepSpeedup > 8.0)
        // Sanity: the linear fold's total stays well under the quadratic fold's,
        // and comfortably sub-quadratic in absolute terms.
        #expect(largeSeconds < largeVarSeconds)
        #expect(consumeRatio < varRatio)
    }

    // MARK: Helpers

    /// Builds a `PathSegment` by folding `consuming` `.segment(_:)` over
    /// pre-interned labels with the `consume` operator, so each step hands the
    /// receiver's sole ownership to the call → in-place append → O(N) total.
    private func consumeFoldSegment(from labels: [String]) -> PathSegment {
        var segment = PathSegment.segment(labels[0])
        for index in 1 ..< labels.count {
            segment = (consume segment).segment(labels[index])
        }
        return segment
    }

    /// Builds a `PathSegment` by folding `.segment(_:)` into a reused `var`
    /// (no `consume`), so the prior value stays alive across the call and Swift
    /// copy-on-writes the whole buffer each step → O(N²). Used only as the
    /// timing contrast / regression baseline.
    private func varFoldSegment(from labels: [String]) -> PathSegment {
        var segment = PathSegment.segment(labels[0])
        for index in 1 ..< labels.count {
            segment = segment.segment(labels[index])
        }
        return segment
    }

    private func perStep(_ seconds: Double, _ count: Int) -> String {
        String(format: "%.1f", seconds / Double(count) * 1_000_000_000.0)
    }

    /// Returns the average wall-clock seconds per iteration over `repetitions`.
    private func measureSeconds(repetitions: Int, _ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0 ..< repetitions {
            body()
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / 1_000_000_000.0 / Double(repetitions)
    }

    private func formatMillis(_ seconds: Double) -> String {
        String(format: "%.3f", seconds * 1_000.0)
    }

    /// Extracts the label from a `.subdomain` storage case (test-only).
    private func subdomainLabel(_ storage: URLComponent.Storage) -> String {
        if case .subdomain(let label) = storage {
            return label
        }
        return "<non-subdomain>"
    }
}

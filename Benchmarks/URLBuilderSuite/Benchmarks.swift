import Benchmark
import URLBuilder

// URLBuilder's benchmark suite on ordo-one's `Benchmark` framework, matching the sibling packages.
// Run with `URLBUILDER_DEV=1 swift package benchmark` (add `BENCHMARK_DISABLE_JEMALLOC=1` if jemalloc
// isn't installed; CI installs it for malloc metrics). The suite covers the three runtime hot paths a
// consumer pays for: assembling a `URL` from the result-builder DSL across representative shapes, the
// query/percent-encoding cost as query count grows, and the public-suffix `longestMatch` lookup that
// backs TLD enforcement. (The macros — `#URL`/`@URLQuery` — are compile-time and don't appear here.)

nonisolated(unsafe) let benchmarks = {
    Benchmark.defaultConfiguration = .init(metrics: [.wallClock, .throughput])

    // `.mallocCountTotal` guards the allocation profile of the assembly/encoding paths so a
    // reintroduced intermediate `String`/array copy fails a threshold instead of silently rotting
    // (collected in CI, where jemalloc is installed).
    let allocMetrics = Benchmark.Configuration(metrics: [.wallClock, .throughput, .mallocCountTotal])

    // MARK: URL assembly — the result-builder DSL → URL, across representative shapes (the path every
    // consumer hits). Side by side so the marginal cost of each added component is directly comparable.
    Benchmark("url/scheme+domain+tld", configuration: allocMetrics) { bm in
        for _ in bm.scaledIterations {
            blackHole(
                URLBuilder {
                    HTTPS {
                        Domain("apple")
                        TLD.com
                    }
                })
        }
    }
    Benchmark("url/+single-query", configuration: allocMetrics) { bm in
        for _ in bm.scaledIterations {
            blackHole(
                URLBuilder {
                    HTTPS {
                        Domain("apple")
                        TLD.com
                        Query("q", "swift")
                    }
                })
        }
    }
    Benchmark("url/subdomain+path+query+fragment", configuration: allocMetrics) { bm in
        for _ in bm.scaledIterations {
            blackHole(
                URLBuilder {
                    HTTPS {
                        Subdomain("www")
                        Domain("apple")
                        TLD.com
                        Port(443)
                        Path("v1", "items", "42")
                        Query("q", "swift")
                        Query("sort", "asc")
                        Fragment("section-3")
                    }
                })
        }
    }

    // MARK: query encoding — cost as the query count grows, with reserved characters that force
    // percent-encoding (spaces, `&`, `/`, `?`, `=`, non-ASCII). This is the framing/encoding hot path.
    let queryPairs: [(String, String)] = [
        ("q", "swift concurrency"), ("filter", "kind=symbol&deprecated=false"),
        ("path", "/docs/v1/items?x=1"), ("note", "a=b=c"), ("tag", "iOS 18 / macOS 15"),
        ("name", "Pequeña Niña"), ("emoji", "rocket 🚀 launch"), ("sort", "asc"),
        ("page", "3"), ("limit", "25"), ("ref", "home#top"), ("u", "user@example.com")
    ]
    for count in [4, 12] {
        let pairs = Array(queryPairs.prefix(count))
        Benchmark("url/query-heavy \(count) items (percent-encode)", configuration: allocMetrics) { bm in
            for _ in bm.scaledIterations {
                blackHole(
                    URLBuilder {
                        HTTPS {
                            Domain("example")
                            TLD.com
                            for (key, value) in pairs { Query(key, value) }
                        }
                    })
            }
        }
    }

    // MARK: public-suffix lookup — `PublicSuffix.longestMatch` (TLD enforcement) across host shapes:
    // a 2-label apex, a multi-label subdomain, a multi-part suffix (`co.uk`), a private suffix
    // (`github.io`), and a no-match host. Run as a batch so one report shows the mixed-host cost.
    let hosts = [
        "apple.com", "www.developer.apple.com", "shop.example.co.uk",
        "pages.github.io", "a.b.c.d.e.example.com", "localhost"
    ]
    Benchmark("psl/longestMatch mixed hosts") { bm in
        for _ in bm.scaledIterations {
            for host in hosts { blackHole(PublicSuffix.longestMatch(for: host)) }
        }
    }
    let suffixes = ["com", "co.uk", "github.io", "not.a.real.suffix"]
    Benchmark("psl/contains mixed suffixes") { bm in
        for _ in bm.scaledIterations {
            for suffix in suffixes { blackHole(PublicSuffix.contains(suffix)) }
        }
    }
}

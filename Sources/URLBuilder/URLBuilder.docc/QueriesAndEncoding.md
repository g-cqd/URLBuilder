# Queries and Encoding

How query values are rendered, how `@URLQuery` synthesizes a query block, and how to choose an
encoding mode.

## Two rendering paths

A ``Query`` value is rendered one of two ways, chosen by overload resolution:

1. **Scalar path** — any ``URLQueryValueConvertible`` renders directly through its
   `urlQueryValue`. Standard library and Foundation scalars conform out of the box: `String`,
   `Substring`, `Bool`, the integer and floating-point types, `Decimal`, `UUID`, and `Date`
   (ISO 8601 with fractional seconds, UTC). `RawRepresentable` enums whose raw value is itself
   convertible get a default conformance.

2. **Encodable path** — any other `Encodable` value renders as **compact JSON** (sorted keys,
   slashes left unescaped), produced by the ADJSON engine. A value that encodes to a top-level
   JSON string is unwrapped to its raw contents rather than a quoted literal.

When a type satisfies *both* (e.g. a `RawRepresentable & Encodable` enum), the scalar path wins —
your declared `urlQueryValue` is preferred over generic JSON.

```swift
HTTPS("example.com") {
    Query("q", "swift")                    // q=swift          (scalar)
    Query("when", Date())                  // when=2026-…Z     (scalar, ISO 8601)
    Query("filter", Filter(status: "open"))// filter={"status":"open"}  (Encodable → JSON)
}
```

### Decimal renders as a plain scalar

`Decimal` conforms to ``URLQueryValueConvertible`` and renders through its base-10 `description`,
so it stays on the scalar path and never routes through the JSON encoder. This keeps the value
encoder-independent and free of binary-`Double` rounding:

```swift
Query("amount", Decimal(string: "0.1234567890123456789")!)
// amount=0.1234567890123456789   (a Double would round at ~17 digits)
```

> Note: Foundation normalizes a `Decimal`'s trailing zeros at construction, so `Decimal(string:
> "10.50")` is already `10.5` before it reaches the query layer — `description` cannot reintroduce
> the trailing zero.

## Synthesizing a query block with `@URLQuery`

Annotate a DTO with `@URLQuery` to synthesize ``URLQueryRepresentable`` from its stored
properties. Per-property behavior is configured with the `@Query` peer:

```swift
@URLQuery
struct Search {
    let q: String                                   // q=<value>
    @Query(.key("page_number")) let page: Int?      // optional → omitted when nil
    let tags: [String]                              // array → repeated key (tags=a&tags=b)
    let ids: Set<Int>                               // set → repeated key, deterministic order
    @Query(.flag) let strict: Bool                  // Bool → value-less flag when true
    @Query(.ignore) let trace: UUID                 // excluded from synthesis
}
```

Two behaviors are worth calling out:

- **Optional collections unfold.** An optional array or set (`[String]?`, `Set<Int>?`) is first
  unwrapped, *then* unfolded to one query item per element — not collapsed to a single value.
- **Sets render deterministically.** `Set` iteration order is unspecified per process, which would
  produce unstable URLs (breaking HMAC signing, cache keys, and snapshot tests). `@URLQuery`
  therefore emits a **sorted** iteration (ordered by each element's `String(describing:)` form —
  lexicographic and stable, not numeric), so the rendered URL is identical on every run.

### Supported property shapes

`@URLQuery` infers each property's shape structurally from its type:

| Shape | Rendering |
|---|---|
| scalar (`String`, `Int`, `UUID`, …) | `Query(key, value)` |
| optional (`Int?`) | `if let` — omitted when `nil` |
| array (`[T]`, `Array<T>`) | one item per element under the same key |
| set (`Set<T>`) | one item per element, sorted for a stable URL |
| optional collection (`[T]?`, `Set<T>?`) | unwrapped, then unfolded |

`@URLQuery` skips members that are not per-instance query state — `static`/`class` and `lazy`
storage, and computed properties — but **keeps** stored properties that carry `willSet`/`didSet`
observers. Every binding of a multi-binding declaration (`let a, b: Int`) is emitted, and a
property whose name is a Swift keyword (e.g. one named `default`) renders under its bare name
(`?default=…`).

### Diagnosed shapes (fail-fast)

Shapes with no canonical query unfold are a **compile-time error** rather than a guessed rendering:

- **Dictionaries** (`[String: Int]`) — encode explicitly with a custom ``URLQueryRepresentable`` or
  exclude with `@Query(.ignore)`.
- **Nested optionals** (`Int??`) — flatten to a single optional, or exclude.
- **Un-annotated collection literals** (`let tags = ["ios"]`) — add an explicit `[T]` / `Set<T>`
  annotation so the property unfolds instead of silently JSON-encoding the literal.

## Encoding modes

``URLBuildConfiguration`` selects how query items are percent-encoded via
``URLBuildConfiguration/QueryEncoding``:

- `.rfc3986` (default) — items are encoded by Foundation `URLComponents`.
- `.formURLEncoded` — WHATWG `application/x-www-form-urlencoded`: SPACE becomes `+`, a literal `+`
  becomes `%2B`, and the remaining reserved bytes are percent-encoded as UTF-8.

## Deduplication

``URLBuildConfiguration/QueryDeduplication`` controls what happens when a key repeats: `.none`
keeps all, `.firstWins` and `.lastWins` collapse to a single item kept at the first occurrence's
position (matching `URLSearchParams.set` placement).

## Topics

### Query values

- ``Query``
- ``URLQueryValue``
- ``URLQueryValueConvertible``
- ``URLQueryRepresentable``

### Configuration

- ``URLBuildConfiguration``

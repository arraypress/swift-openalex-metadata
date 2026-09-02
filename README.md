# Swift OpenAlex

250 million works and the citation graph joining them — as typed values, keyless, on any Apple platform.

```swift
import OpenAlexMetadata

let openAlex = OpenAlex(mailto: "you@example.com")
let work = try await openAlex.work("10.1038/nature12373")

print(work.citation)        // Kucsko G, Maurer PC, Yao NY, et al. (2013). … Nature 500(7460):54-58
print(work.citedByCount)    // 1988

let citing = try await openAlex.citedBy(work.key)      // who built on it
let cited  = try await openAlex.references(of: work.key) // what it stood on
```

## Features

- 🕸️ **The citation graph, both directions** — `citedBy` walks inbound edges, `references` outbound. The two filters are trivially transposed, so the library names them once and gets the direction right: verified against a record with 1,989 citations and 34 references
- 🆔 **Any identifier** — an OpenAlex key, a DOI in any form, a PubMed ID, or a full openalex.org URL. Normalised to the character, and a bare key costs one request where a DOI costs two — rather than both costing two
- 📄 **Cursor paging** — OpenAlex caps offset paging at 10,000 rows, so anything walking a large result set needs the cursor. `Page` carries the total, the page size and `nextCursor` together
- 🔢 **The count is often the whole answer** — "372,791 works match" costs one request for one row
- 🚪 **A filter escape hatch** — OpenAlex's filter language is large and moves faster than any wrapper. `works(filter:)` takes the raw expression, so `from_publication_date:2024-01-01,type:article` needs no new enum case
- 🛑 **A stopped query is not a server error** — OpenAlex reports an over-broad query as a 5xx with `reason: query_timeout`. That becomes a typed `queryTooBroad`, because the fix is a narrower query, not a retry
- 🚦 **429s handled like an adult** — Retry-After honoured and capped at ten seconds, two retries, then a typed `rateLimited` error
- 📏 **Page sizes clamped locally** — 1…200, rather than letting the API 400 on the caller's behalf
- 📼 **Tested on recordings** — 17 tests on real captured output with an injected transport. No network, no flakiness

## The `mailto` is optional, and worth sending

Supplying an address puts requests in OpenAlex's *polite pool* — a faster, more
reliable rate-limit bucket. It is not a credential and there is no key to obtain;
the API works without it, but there is no reason not to.

## Requirements

macOS 14+ / iOS 16+ / tvOS 16+ / watchOS 9+ / visionOS 1+, Swift 6. Foundation only.

## License

MIT — see LICENSE.

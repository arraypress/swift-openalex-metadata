//
//  OpenAlex.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  OpenAlex as typed values — 250 million works and the citation graph
//  joining them, keyless. The successor to Microsoft Academic Graph, and
//  the reason "what cites this" is answerable at all without a licence.
//
//  Two filters do the citation work and they are easy to transpose, so
//  they are named here once: `cites:W…` finds works citing that one,
//  `cited_by:W…` finds the works it cites. Verified against a record with
//  1,989 citations and 34 references on 2026-09-03.
//

import Foundation

/// A keyless client for OpenAlex.
public struct OpenAlex: Sendable {

    /// How requests are performed — injectable so tests run on recordings.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// How a retry waits — injectable so rate-limit tests cost no wall-clock.
    public typealias Sleeper = @Sendable (_ seconds: Int) async throws -> Void

    /// The User-Agent sent when none is chosen.
    public static let defaultUserAgent = "swift-openalex/0.1 (+https://github.com/arraypress/swift-openalex-metadata)"

    /// The largest page OpenAlex will return.
    public static let maxPerPage = 200

    /// An address that puts requests in the polite pool — a faster, more
    /// reliable rate-limit bucket. Optional, and the API works without it,
    /// but supplying one is both free and courteous.
    public let mailto: String?

    /// The User-Agent every request carries.
    public let userAgent: String

    private let transport: Transport
    private let sleeper: Sleeper

    /// A client.
    ///
    /// - Parameters:
    ///   - mailto: An address you read. Optional; it buys the polite pool.
    ///   - userAgent: Identify yourself.
    ///   - transport: Leave `nil` for the shared URLSession.
    ///   - sleeper: How a 429 retry waits; leave `nil` for real sleeping.
    public init(mailto: String? = nil, userAgent: String = OpenAlex.defaultUserAgent,
                transport: Transport? = nil, sleeper: Sleeper? = nil) {
        self.mailto = mailto
        self.userAgent = userAgent
        self.sleeper = sleeper ?? { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(seconds, 1)) * 1_000_000_000)
        }
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OpenAlexError.malformed("not an HTTP response")
            }
            return (data, http)
        }
    }

    // MARK: - Works

    /// One work, by OpenAlex key, DOI, or PubMed ID.
    public func work(_ id: String) async throws -> Work {
        try await decode(Work.self, from: Endpoint.entity("works", id: id, mailto: mailto))
    }

    /// Works matching free text.
    ///
    /// - Parameters:
    ///   - query: What to search for.
    ///   - sort: Ordering; relevance by default.
    ///   - perPage: 1…200.
    ///   - cursor: `*` to start cursor paging, then a previous
    ///     ``Page/nextCursor``. Needed beyond 10,000 rows.
    public func works(matching query: String, sort: ResultOrder = .relevance,
                      perPage: Int = 25, cursor: String? = nil) async throws -> Page<Work> {
        let url = try Endpoint.list("works", search: query, sort: sort,
                                    perPage: clamp(perPage), cursor: cursor, mailto: mailto)
        return try await decode(Page<Work>.self, from: url)
    }

    /// Works matching a raw OpenAlex filter expression.
    ///
    /// The escape hatch: OpenAlex's filter language is large and moves
    /// faster than a wrapper can, so callers who need
    /// `from_publication_date:2024-01-01,type:article` can say exactly
    /// that rather than wait for an enum case.
    public func works(filter: String, sort: ResultOrder = .relevance,
                      perPage: Int = 25, cursor: String? = nil) async throws -> Page<Work> {
        let url = try Endpoint.list("works", filter: filter, sort: sort,
                                    perPage: clamp(perPage), cursor: cursor, mailto: mailto)
        return try await decode(Page<Work>.self, from: url)
    }

    /// The works that CITE this one.
    ///
    /// Note the direction — this is the inbound edge, the one that answers
    /// "who built on this".
    public func citedBy(_ id: String, sort: ResultOrder = .newest,
                        perPage: Int = 25, cursor: String? = nil) async throws -> Page<Work> {
        guard let key = EntityID.openAlexKey(in: try await resolveKey(id)) else {
            throw OpenAlexError.badIdentifier(id)
        }
        return try await works(filter: "cites:\(key)", sort: sort, perPage: perPage, cursor: cursor)
    }

    /// The works this one CITES — its reference list, as records.
    public func references(of id: String, sort: ResultOrder = .newest,
                           perPage: Int = 25, cursor: String? = nil) async throws -> Page<Work> {
        guard let key = EntityID.openAlexKey(in: try await resolveKey(id)) else {
            throw OpenAlexError.badIdentifier(id)
        }
        return try await works(filter: "cited_by:\(key)", sort: sort, perPage: perPage, cursor: cursor)
    }

    // MARK: - Authors

    /// One author, by OpenAlex key or ORCID.
    public func author(_ id: String) async throws -> Author {
        try await decode(Author.self, from: Endpoint.entity("authors", id: id, mailto: mailto))
    }

    /// Authors matching a name.
    public func authors(matching query: String, perPage: Int = 25,
                        cursor: String? = nil) async throws -> Page<Author> {
        let url = try Endpoint.list("authors", search: query, perPage: clamp(perPage),
                                    cursor: cursor, mailto: mailto)
        return try await decode(Page<Author>.self, from: url)
    }

    /// Everything an author wrote.
    public func works(byAuthor id: String, sort: ResultOrder = .newest,
                      perPage: Int = 25, cursor: String? = nil) async throws -> Page<Work> {
        guard let key = EntityID.openAlexKey(in: try await resolveKey(id)) else {
            throw OpenAlexError.badIdentifier(id)
        }
        return try await works(filter: "author.id:\(key)", sort: sort, perPage: perPage, cursor: cursor)
    }

    // MARK: - Plumbing

    /// Turns any identifier into an OpenAlex key, looking the work up only
    /// when it is not already one — so `citedBy("W123")` costs one request
    /// and `citedBy("10.1038/…")` costs two, rather than both costing two.
    private func resolveKey(_ id: String) async throws -> String {
        if let key = EntityID.openAlexKey(in: id) { return key }
        return try await work(id).key
    }

    /// Clamps a page size into the range the API accepts, rather than
    /// letting it 400 on the caller's behalf.
    private func clamp(_ perPage: Int) -> Int { min(max(perPage, 1), Self.maxPerPage) }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let data = try await perform(url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw OpenAlexError.malformed("\(error)")
        }
    }

    /// Performs a GET with the User-Agent, retrying a 429 twice with the
    /// service's own Retry-After (capped at ten seconds) before giving up.
    func perform(_ url: URL, retriesLeft: Int = 2) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await transport(request)
        switch response.statusCode {
        case 200...299:
            return data
        case 404:
            throw OpenAlexError.notFound(url.lastPathComponent)
        case 403:
            // OpenAlex uses 403 for a malformed filter as well as refusal;
            // its body says which, so it is passed through verbatim.
            throw OpenAlexError.badIdentifier(String(data: data, encoding: .utf8) ?? url.absoluteString)
        case 429:
            let after = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            guard retriesLeft > 0 else { throw OpenAlexError.rateLimited(retryAfter: after) }
            try await sleeper(min(after ?? 1, 10))
            return try await perform(url, retriesLeft: retriesLeft - 1)
        case 500...599:
            // A stopped query is reported as a 5xx with a JSON body naming
            // the reason. MEASURED transient: an identical trivial filter
            // failed three times then succeeded three times unchanged, so it
            // is retried like a 429 rather than handed straight to the
            // caller. Only when the retries are spent does it surface — and
            // then as its own case, because "narrow the query" is at least
            // worth suggesting once a retry has already failed twice.
            if let body = try? JSONDecoder().decode(ServerError.self, from: data), body.reason == "query_timeout" {
                guard retriesLeft > 0 else {
                    throw OpenAlexError.queryStopped(body.message ?? "query timed out")
                }
                try await sleeper(1)
                return try await perform(url, retriesLeft: retriesLeft - 1)
            }
            throw OpenAlexError.http(response.statusCode)
        default:
            throw OpenAlexError.http(response.statusCode)
        }
    }

    /// The error envelope OpenAlex returns for a stopped query.
    struct ServerError: Decodable {
        let error: String?
        let message: String?
        let reason: String?
    }
}

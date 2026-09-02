//
//  Endpoint.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  Query building, split from the client so every parameter can be
//  asserted without a network. `mailto` is what puts a caller in the
//  polite pool — a faster, more reliable rate-limit bucket — so it is
//  attached here, once, rather than remembered at each call site.
//

import Foundation

/// OpenAlex's REST surface.
enum Endpoint {

    /// The API root.
    static let base = "https://api.openalex.org"

    /// One entity by identifier.
    static func entity(_ collection: String, id: String, mailto: String?) throws -> URL {
        let path = EntityID.path(for: id)
        guard !path.isEmpty else { throw OpenAlexError.badIdentifier(id) }
        var components = URLComponents(string: "\(base)/\(collection)/\(path)")
        components?.queryItems = mailtoItems(mailto)
        guard let url = components?.url else { throw OpenAlexError.badIdentifier(id) }
        return url
    }

    /// A search or filter over a collection.
    ///
    /// - Parameters:
    ///   - search: Free text. Omitted entirely when `nil`, because an
    ///     empty `search=` is not the same as no search to the API.
    ///   - filter: Raw filter expression, e.g. `cites:W2159974629`.
    ///   - sort: The ordering, or `nil` for the API's own default.
    ///   - perPage: 1…200; the API rejects more.
    ///   - cursor: `*` to begin cursor paging, then the previous page's
    ///     `next_cursor`. Mutually exclusive with `page`.
    ///   - page: Offset paging, capped upstream at 10,000 rows total.
    static func list(_ collection: String, search: String? = nil, filter: String? = nil,
                     sort: ResultOrder? = nil, perPage: Int = 25, cursor: String? = nil,
                     page: Int? = nil, select: [String]? = nil, mailto: String?) throws -> URL {
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
        if let filter, !filter.isEmpty { items.append(URLQueryItem(name: "filter", value: filter)) }
        if let sortParameter = sort?.parameter { items.append(URLQueryItem(name: "sort", value: sortParameter)) }
        items.append(URLQueryItem(name: "per-page", value: String(perPage)))
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        else if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let select, !select.isEmpty { items.append(URLQueryItem(name: "select", value: select.joined(separator: ","))) }
        items += mailtoItems(mailto)

        var components = URLComponents(string: "\(base)/\(collection)")
        components?.queryItems = items
        guard let url = components?.url else { throw OpenAlexError.badIdentifier(collection) }
        return url
    }

    /// The polite-pool parameter, when an address was given.
    private static func mailtoItems(_ mailto: String?) -> [URLQueryItem] {
        guard let mailto, !mailto.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return [URLQueryItem(name: "mailto", value: mailto)]
    }
}

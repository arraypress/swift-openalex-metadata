//
//  Page.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  One page of results plus the count and the cursor to continue from.
//  The count matters as much as the rows: "372,791 works match" is often
//  the whole answer, and getting it costs one request for one row.
//

import Foundation

/// A page of entities, with the total and a way to continue.
public struct Page<Item: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {

    /// The rows on this page.
    public let results: [Item]
    /// How many match in total, across every page.
    public let count: Int
    /// How many rows a page holds.
    public let perPage: Int?
    /// The cursor for the next page, or `nil` at the end.
    ///
    /// Cursor paging, not page numbers: OpenAlex caps offset paging at
    /// 10,000 rows, so anything that walks a large result set must use
    /// this.
    public let nextCursor: String?

    enum CodingKeys: String, CodingKey { case results, meta }

    /// Camel-cased on purpose. The client decodes with
    /// `.convertFromSnakeCase`, which rewrites `next_cursor` to
    /// `nextCursor` BEFORE keys are matched here — so spelling these in
    /// the wire's snake_case silently yields `nil`, which is exactly the
    /// bug this comment exists to stop happening twice.
    enum MetaKeys: String, CodingKey { case count, perPage, nextCursor }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([Item].self, forKey: .results) ?? []
        let meta = try container.nestedContainer(keyedBy: MetaKeys.self, forKey: .meta)
        count = try meta.decodeIfPresent(Int.self, forKey: .count) ?? results.count
        perPage = try meta.decodeIfPresent(Int.self, forKey: .perPage)
        nextCursor = try meta.decodeIfPresent(String.self, forKey: .nextCursor)
    }

    public init(results: [Item], count: Int, perPage: Int? = nil, nextCursor: String? = nil) {
        self.results = results
        self.count = count
        self.perPage = perPage
        self.nextCursor = nextCursor
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(results, forKey: .results)
        var meta = container.nestedContainer(keyedBy: MetaKeys.self, forKey: .meta)
        try meta.encode(count, forKey: .count)
        try meta.encodeIfPresent(perPage, forKey: .perPage)
        try meta.encodeIfPresent(nextCursor, forKey: .nextCursor)
    }
}

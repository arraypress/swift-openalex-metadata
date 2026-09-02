//
//  OpenAlexError.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong talking to OpenAlex.
public enum OpenAlexError: Error, LocalizedError, Sendable, Equatable {
    /// The identifier given could not be put into a request.
    case badIdentifier(String)
    /// OpenAlex has no such entity.
    case notFound(String)
    /// OpenAlex stopped the query before it completed.
    ///
    /// Its message blames query breadth, and sometimes that is right — but
    /// MEASURED on 2026-09-03, a trivial `cites:W…` filter returned this
    /// three times and then succeeded three times unchanged. So it is
    /// primarily a transient load signal, and a retry is the first thing
    /// to try, not a rewrite of the query.
    case queryStopped(String)
    /// OpenAlex answered with an HTTP failure.
    case http(Int)
    /// OpenAlex is rate-limiting; retry after this many seconds if known.
    case rateLimited(retryAfter: Int?)
    /// A response did not have the shape the API documents.
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .badIdentifier(let id): return "\(id) is not an identifier OpenAlex can look up"
        case .notFound(let id): return "OpenAlex has no record of \(id)"
        case .queryStopped(let why): return "OpenAlex stopped the query before it completed: \(why)"
        case .http(let code): return "OpenAlex answered HTTP \(code)"
        case .rateLimited(let after):
            return "OpenAlex is rate-limiting" + (after.map { " (retry after \($0)s)" } ?? "")
        case .malformed(let what): return "unexpected response shape: \(what)"
        }
    }
}

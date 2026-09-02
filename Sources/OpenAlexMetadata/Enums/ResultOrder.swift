//
//  ResultOrder.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  The orderings worth naming. OpenAlex accepts more, but these are the
//  ones a caller asks for out loud, and a closed set means a typo is a
//  compile error rather than a silently unsorted result set.
//
//  Named ResultOrder rather than the obvious SortOrder because Foundation
//  already has a SortOrder, and any consumer importing both would get
//  "ambiguous for type lookup" on a name they never chose.
//

import Foundation

/// How results come back.
public enum ResultOrder: String, Sendable, CaseIterable {
    /// Best textual match. The API's default when searching.
    case relevance
    /// Most cited first — the closest thing to "most important".
    case citations
    /// Newest first.
    case newest
    /// Oldest first.
    case oldest

    /// The `sort` parameter this maps to, or `nil` to let the API decide.
    var parameter: String? {
        switch self {
        case .relevance: return nil
        case .citations: return "cited_by_count:desc"
        case .newest: return "publication_date:desc"
        case .oldest: return "publication_date:asc"
        }
    }
}

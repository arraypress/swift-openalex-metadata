//
//  Work+Derived.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  The questions callers ask, answered once here instead of at every call
//  site. Kept out of the model file so ``Work`` stays a description of the
//  API's shape and nothing else.
//

import Foundation

public extension Work {

    /// The bare OpenAlex key — `W2159974629` — for use in filters.
    var key: String { EntityID.openAlexKey(in: id) ?? id }

    /// The DOI without its resolver prefix, lower-cased.
    var bareDOI: String? {
        guard let doi else { return nil }
        let stripped = EntityID.normalizedDOI(doi)
        return stripped.hasPrefix("10.") ? stripped : nil
    }

    /// Whether a free copy exists anywhere OpenAlex can see.
    var isFree: Bool { openAccess?.isOa ?? false }

    /// The best link to read it free, if there is one.
    var readableURL: URL? {
        if let oa = openAccess?.oaUrl, let url = URL(string: oa) { return url }
        return primaryLocation?.bestURL
    }

    /// The journal or repository it appeared in.
    var venue: String? { primaryLocation?.source?.displayName }

    /// Author names in order, shortened for a citation line.
    var authorNames: [String] {
        (authorships ?? []).compactMap { authorship in
            let short = authorship.author?.short ?? ""
            if !short.isEmpty { return short }
            // Fall back to the printed name when the person was not resolved.
            return authorship.rawAuthorName
        }
    }

    /// A one-line citation: `Doudna JA, et al. (2013). Title. Nature 500(7460):54-58.`
    var citation: String {
        var parts: [String] = []
        let names = authorNames
        if !names.isEmpty {
            // No trailing stop on "et al" — the join below supplies it.
            parts.append(names.prefix(3).joined(separator: ", ") + (names.count > 3 ? ", et al" : ""))
        }
        if let publicationYear { parts.append("(\(publicationYear))") }
        if let title { parts.append(title) }
        if let venue {
            parts.append(biblio?.reference.map { "\(venue) \($0)" } ?? venue)
        }
        return parts.joined(separator: ". ")
    }
}

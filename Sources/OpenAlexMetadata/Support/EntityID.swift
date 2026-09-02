//
//  EntityID.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  OpenAlex will look a work up by any of four identifiers, and callers
//  have whichever one they happened to be handed. Turning them all into
//  the path segment the API wants is a pure function, so it is asserted
//  to the character rather than discovered in production.
//

import Foundation

/// The identifiers OpenAlex accepts, normalised to a path segment.
public enum EntityID {

    /// The path segment for whatever identifier `raw` is.
    ///
    /// Recognises, in order:
    /// - a full OpenAlex URL — `https://openalex.org/W2159974629`
    /// - a bare OpenAlex key — `W2159974629`, `A5067184382`
    /// - a DOI in any form, which becomes `doi:10.…`
    /// - a PubMed ID, which becomes `pmid:…`
    ///
    /// Anything else is passed through untouched, so a form added upstream
    /// still reaches the API rather than being mangled on the way out.
    public static func path(for raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }

        if let key = openAlexKey(in: text) { return key }
        if text.lowercased().hasPrefix("pmid:") { return "pmid:" + text.dropFirst(5) }
        if text.lowercased().hasPrefix("doi:") { return "doi:" + normalizedDOI(String(text.dropFirst(4))) }
        if looksLikeDOI(text) { return "doi:" + normalizedDOI(text) }
        if text.allSatisfy(\.isNumber) { return "pmid:" + text }
        return text
    }

    /// The bare OpenAlex key — `W2159974629` — from a key or its URL.
    ///
    /// Entity letters are W(ork), A(uthor), S(ource), I(nstitution),
    /// T(opic), P(ublisher), F(under), C(oncept).
    public static func openAlexKey(in raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = text.hasPrefix("https://openalex.org/") || text.hasPrefix("http://openalex.org/")
            ? String(text.split(separator: "/").last ?? "")
            : text
        guard let first = candidate.first, "WASITPFC".contains(first.uppercased()),
              candidate.count > 1, candidate.dropFirst().allSatisfy(\.isNumber) else { return nil }
        return candidate.uppercased()
    }

    /// Whether this looks like a DOI rather than something else.
    static func looksLikeDOI(_ text: String) -> Bool {
        normalizedDOI(text).hasPrefix("10.")
    }

    /// A DOI stripped of its resolver, lower-cased.
    static func normalizedDOI(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://doi.org/", "http://doi.org/", "https://dx.doi.org/", "http://dx.doi.org/"]
        where text.lowercased().hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            break
        }
        return text.lowercased()
    }
}

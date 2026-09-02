//
//  Location.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  Where a work appeared, and the venue it appeared in. OpenAlex models
//  these separately — a location is a copy, a source is the journal or
//  repository holding it — and keeping that split makes "which journal"
//  and "which copy" answerable independently.
//

import Foundation

/// One place a work can be found.
public struct Location: Codable, Sendable, Equatable {
    public let isOa: Bool?
    public let landingPageUrl: String?
    public let pdfUrl: String?
    public let license: String?
    /// `publishedVersion`, `acceptedVersion` or `submittedVersion`.
    public let version: String?
    /// The venue this copy sits in.
    public let source: Source?

    /// The most directly useful link: the PDF if there is one, else the
    /// landing page.
    public var bestURL: URL? {
        for candidate in [pdfUrl, landingPageUrl] {
            if let candidate, let url = URL(string: candidate) { return url }
        }
        return nil
    }
}

/// A journal, conference, repository or book series.
public struct Source: Codable, Sendable, Equatable {
    public let id: String?
    public let displayName: String?
    /// The linking ISSN — the one to use as a stable venue key.
    public let issnL: String?
    /// `journal`, `repository`, `conference`, `book series`…
    public let type: String?
    /// The publisher or hosting organisation.
    public let hostOrganizationName: String?
    /// Whether the venue itself is fully open access.
    public let isOa: Bool?
    /// Whether it is listed in the DOAJ.
    public let isInDoaj: Bool?
}

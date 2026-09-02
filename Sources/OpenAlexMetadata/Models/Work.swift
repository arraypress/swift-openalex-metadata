//
//  Work.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  One work in OpenAlex. The full record is enormous — well over a
//  hundred fields, most of them nested — so this decodes the subset that
//  answers the questions people actually ask of a citation graph: what is
//  it, who wrote it, where did it appear, is it free, and how connected
//  is it. Unknown fields are ignored rather than fatal, so OpenAlex adding
//  to the record cannot break a caller.
//

import Foundation

/// A paper, dataset, book or other work.
public struct Work: Codable, Sendable, Equatable {

    /// The OpenAlex URL, e.g. `https://openalex.org/W2159974629`.
    public let id: String
    /// The DOI as a resolver URL, when one exists.
    public let doi: String?
    /// The title. OpenAlex also calls this `display_name`.
    public let title: String?
    /// Year of publication.
    public let publicationYear: Int?
    /// Date of publication, `yyyy-MM-dd`.
    public let publicationDate: String?
    /// The kind of work — `article`, `preprint`, `book-chapter`, `dataset`…
    public let type: String?
    /// Primary language, ISO 639-1.
    public let language: String?
    /// How many works cite this one.
    public let citedByCount: Int?
    /// How many works this one cites.
    public let referencedWorksCount: Int?
    /// Whether the work has been retracted. Worth surfacing loudly.
    public let isRetracted: Bool?
    /// Whether it is front/back matter rather than a work in its own right.
    public let isParatext: Bool?
    /// Field-weighted citation impact, when computed.
    public let fwci: Double?

    /// Every identifier OpenAlex holds for this work.
    public let ids: Identifiers?
    /// Open-access position.
    public let openAccess: OpenAccess?
    /// Where it was published.
    public let primaryLocation: Location?
    /// Who wrote it, in order.
    public let authorships: [Authorship]?
    /// Volume, issue and pages.
    public let biblio: Biblio?
    /// A URL that lists this work's references, for follow-up queries.
    public let referencedWorks: [String]?

    /// The identifiers a caller might want to cross-reference with.
    public struct Identifiers: Codable, Sendable, Equatable {
        public let openalex: String?
        public let doi: String?
        public let mag: String?
        public let pmid: String?
        public let pmcid: String?
    }

    /// Whether, and how, the work is free to read.
    public struct OpenAccess: Codable, Sendable, Equatable {
        public let isOa: Bool?
        /// `gold`, `green`, `hybrid`, `bronze`, `closed` or `diamond`.
        public let oaStatus: String?
        /// The best free URL OpenAlex knows.
        public let oaUrl: String?
        public let anyRepositoryHasFulltext: Bool?
    }

    /// Volume, issue and page range.
    public struct Biblio: Codable, Sendable, Equatable {
        public let volume: String?
        public let issue: String?
        public let firstPage: String?
        public let lastPage: String?

        /// `500(7460):54-58` — the tail of a citation line.
        public var reference: String? {
            guard let volume else { return nil }
            let issuePart = issue.map { "(\($0))" } ?? ""
            guard let firstPage else { return volume + issuePart }
            let pages = lastPage.map { "\(firstPage)-\($0)" } ?? firstPage
            return "\(volume)\(issuePart):\(pages)"
        }
    }
}

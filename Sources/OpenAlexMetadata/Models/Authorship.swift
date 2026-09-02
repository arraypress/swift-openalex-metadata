//
//  Authorship.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  One person's contribution to one work. OpenAlex separates the person
//  (an Author entity with a stable ID and an ORCID) from the credit on a
//  particular paper (position, affiliation at the time), which is what
//  makes "everything this person wrote" a real query rather than a string
//  match on a name.
//

import Foundation

/// One author's credit on one work.
public struct Authorship: Codable, Sendable, Equatable {
    /// `first`, `middle` or `last`.
    public let authorPosition: String?
    /// The person.
    public let author: Author?
    /// Whether they are the corresponding author.
    public let isCorresponding: Bool?
    /// The name exactly as printed on this paper.
    public let rawAuthorName: String?
    /// Their affiliations at the time of this work.
    public let institutions: [Institution]?
}

/// A person, as a first-class entity with a stable identifier.
public struct Author: Codable, Sendable, Equatable {
    /// The OpenAlex URL, e.g. `https://openalex.org/A5067184382`.
    public let id: String?
    public let displayName: String?
    /// Their ORCID URL, when known.
    public let orcid: String?
    /// How many works OpenAlex attributes to them.
    public let worksCount: Int?
    /// How many citations those works have collected.
    public let citedByCount: Int?
    /// Where they were most recently seen working.
    public let lastKnownInstitutions: [Institution]?

    /// `Doudna JA` — the form a citation line wants.
    public var short: String {
        guard let name = displayName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return "" }
        let parts = name.split(separator: " ")
        guard parts.count > 1, let last = parts.last else { return name }
        let initials = parts.dropLast().compactMap(\.first).map(String.init).joined()
        return "\(last) \(initials)"
    }
}

/// A university, company or other organisation.
public struct Institution: Codable, Sendable, Equatable {
    public let id: String?
    public let displayName: String?
    /// The Research Organization Registry ID.
    public let ror: String?
    /// ISO 3166-1 alpha-2.
    public let countryCode: String?
    /// `education`, `company`, `government`, `healthcare`…
    public let type: String?
}

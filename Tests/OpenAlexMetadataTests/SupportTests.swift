//
//  SupportTests.swift
//  OpenAlexMetadataTests
//
//  Created by David Sherlock on 2026.
//
//  The extracted utilities on their own: identifier normalising to the
//  character, and the query builder without a network.
//

import Foundation
import XCTest
@testable import OpenAlexMetadata

final class SupportTests: XCTestCase {

    func testIdentifiersNormaliseToThePathTheAPIWants() {
        XCTAssertEqual(EntityID.path(for: "W2159974629"), "W2159974629")
        XCTAssertEqual(EntityID.path(for: "https://openalex.org/W2159974629"), "W2159974629")
        XCTAssertEqual(EntityID.path(for: "w2159974629"), "W2159974629", "keys are upper-cased")
        XCTAssertEqual(EntityID.path(for: "10.1038/nature12373"), "doi:10.1038/nature12373")
        XCTAssertEqual(EntityID.path(for: "https://doi.org/10.1038/Nature12373"), "doi:10.1038/nature12373")
        XCTAssertEqual(EntityID.path(for: "doi:10.1038/nature12373"), "doi:10.1038/nature12373")
        XCTAssertEqual(EntityID.path(for: "33301246"), "pmid:33301246", "bare digits are a PubMed ID")
        XCTAssertEqual(EntityID.path(for: "pmid:33301246"), "pmid:33301246")
    }

    func testAnUnknownFormIsPassedThroughRatherThanMangled() {
        // Something OpenAlex adds later should still reach the API.
        XCTAssertEqual(EntityID.path(for: "ror:01an7q238"), "ror:01an7q238")
        XCTAssertEqual(EntityID.path(for: ""), "")
    }

    func testOpenAlexKeyRecognisesEveryEntityLetterAndRefusesOtherThings() {
        for letter in ["W", "A", "S", "I", "T", "P", "F", "C"] {
            XCTAssertEqual(EntityID.openAlexKey(in: "\(letter)123"), "\(letter)123")
        }
        XCTAssertNil(EntityID.openAlexKey(in: "Z123"), "Z is not an entity type")
        XCTAssertNil(EntityID.openAlexKey(in: "W"), "a letter alone is not a key")
        XCTAssertNil(EntityID.openAlexKey(in: "W12A4"), "the tail must be digits")
        XCTAssertNil(EntityID.openAlexKey(in: "10.1038/nature12373"))
    }

    func testListURLCarriesExactlyTheAskedParameters() throws {
        let url = try Endpoint.list("works", search: "crispr", sort: .citations,
                                    perPage: 50, cursor: "*", mailto: "a@b.com")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items, [
            URLQueryItem(name: "search", value: "crispr"),
            URLQueryItem(name: "sort", value: "cited_by_count:desc"),
            URLQueryItem(name: "per-page", value: "50"),
            URLQueryItem(name: "cursor", value: "*"),
            URLQueryItem(name: "mailto", value: "a@b.com"),
        ])
    }

    func testRelevanceSendsNoSortAndAnAbsentMailtoSendsNoParameter() throws {
        let url = try Endpoint.list("works", search: "x", sort: .relevance, perPage: 25, mailto: nil)
        let names = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map(\.name)
        XCTAssertFalse(names.contains("sort"), "relevance is the API's own default")
        XCTAssertFalse(names.contains("mailto"))
        XCTAssertFalse(names.contains("filter"))
    }

    func testCursorAndPageAreMutuallyExclusive() throws {
        let url = try Endpoint.list("works", search: "x", perPage: 25, cursor: "abc", page: 5, mailto: nil)
        let names = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map(\.name)
        XCTAssertTrue(names.contains("cursor"))
        XCTAssertFalse(names.contains("page"), "a cursor wins; sending both is a 400")
    }

    func testBiblioRendersTheTailOfACitationLine() {
        XCTAssertEqual(Work.Biblio(volume: "500", issue: "7460", firstPage: "54", lastPage: "58").reference,
                       "500(7460):54-58")
        XCTAssertEqual(Work.Biblio(volume: "12", issue: nil, firstPage: "1", lastPage: nil).reference, "12:1")
        XCTAssertEqual(Work.Biblio(volume: "12", issue: "3", firstPage: nil, lastPage: nil).reference, "12(3)")
        XCTAssertNil(Work.Biblio(volume: nil, issue: "3", firstPage: "1", lastPage: "2").reference,
                     "no volume, no reference")
    }
}

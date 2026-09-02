//
//  OpenAlexMetadataTests.swift
//  OpenAlexMetadata
//
//  Created by David Sherlock on 2026.
//
//  Everything runs on recorded responses — real OpenAlex output for
//  W2159974629, captured 2026-09-03 — so the suite needs no network and
//  cannot be rate-limited into flakiness.
//

import Foundation
import XCTest
@testable import OpenAlexMetadata

final class OpenAlexMetadataTests: XCTestCase {

    /// Real OpenAlex output, verbatim apart from trimming the authorship
    /// list and the fields this library does not decode.
    static let recordedWork = #"""
    {"id":"https://openalex.org/W2159974629","doi":"https://doi.org/10.1038/nature12373","title":"Nanometre-scale thermometry in a living cell","publication_year":2013,"publication_date":"2013-07-30","type":"article","language":"en","cited_by_count":1988,"referenced_works_count":36,"is_retracted":false,"is_paratext":false,"ids":{"openalex":"https://openalex.org/W2159974629","doi":"https://doi.org/10.1038/nature12373","mag":"2159974629","pmid":"https://pubmed.ncbi.nlm.nih.gov/23903748"},"open_access":{"is_oa":true,"oa_status":"bronze","oa_url":"https://www.nature.com/articles/nature12373.pdf","any_repository_has_fulltext":true},"primary_location":{"id":"doi:10.1038/nature12373","is_oa":true,"landing_page_url":"https://doi.org/10.1038/nature12373","pdf_url":"https://www.nature.com/articles/nature12373.pdf","source":{"id":"https://openalex.org/S137773608","display_name":"Nature","issn_l":"0028-0836","issn":["0028-0836","1476-4687"],"is_oa":false,"is_in_doaj":false,"is_core":true,"host_organization":"https://openalex.org/P4310319908","host_organization_name":"Nature Portfolio","host_organization_lineage":["https://openalex.org/P4310319908","https://openalex.org/P4310319965"],"host_organization_lineage_names":["Nature Portfolio","Springer Nature"],"type":"journal"},"license":null,"license_id":null,"version":"publishedVersion","is_accepted":true,"is_published":true,"raw_source_name":"Nature","raw_type":"journal-article"},"biblio":{"volume":"500","issue":"7460","first_page":"54","last_page":"58"},"authorships":[{"author_position":"first","author":{"id":"https://openalex.org/A5033043101","display_name":"Georg Kucsko","orcid":"https://orcid.org/0000-0002-4189-3154"},"is_corresponding":false,"raw_author_name":"G. Kucsko"},{"author_position":"middle","author":{"id":"https://openalex.org/A5102792711","display_name":"Peter C. Maurer","orcid":"https://orcid.org/0000-0001-9033-5135"},"is_corresponding":false,"raw_author_name":"P. C. Maurer"}]}
    """#

    /// A page wrapping that same work.
    static var recordedPage: String {
        #"{"meta":{"count":372791,"per_page":1,"next_cursor":"NEXT"},"results":["# + recordedWork + #"]}"#
    }

    final class Script: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var requests: [URLRequest] = []
        let answer: @Sendable (URLRequest) -> (Int, Data, [String: String])

        init(_ answer: @escaping @Sendable (URLRequest) -> (Int, Data, [String: String])) {
            self.answer = answer
        }

        /// Sync on purpose: NSLock may not be taken directly in an async
        /// frame, but calling a synchronous method that locks is fine.
        private func record(_ request: URLRequest) {
            lock.lock(); requests.append(request); lock.unlock()
        }

        var count: Int { lock.lock(); defer { lock.unlock() }; return requests.count }
        var urls: [String] { lock.lock(); defer { lock.unlock() }; return requests.map { $0.url!.absoluteString } }

        func transport(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            record(request)
            let (code, data, headers) = answer(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code,
                                           httpVersion: nil, headerFields: headers)!
            return (data, response)
        }
    }

    func client(_ script: Script, sleeps: (@Sendable (Int) async throws -> Void)? = nil) -> OpenAlex {
        OpenAlex(mailto: "test@example.com", transport: script.transport, sleeper: sleeps ?? { _ in })
    }

    // MARK: - Decoding

    func testDecodesARealWork() async throws {
        let script = Script { _ in (200, Data(Self.recordedWork.utf8), [:]) }
        let work = try await client(script).work("W2159974629")

        XCTAssertEqual(work.key, "W2159974629")
        XCTAssertEqual(work.bareDOI, "10.1038/nature12373")
        XCTAssertEqual(work.publicationYear, 2013)
        XCTAssertEqual(work.citedByCount, 1988)
        XCTAssertEqual(work.venue, "Nature")
        XCTAssertEqual(work.isRetracted, false)
        XCTAssertTrue(work.isFree)
        XCTAssertEqual(work.readableURL?.absoluteString, "https://www.nature.com/articles/nature12373.pdf")
    }

    func testCitationLineReadsLikeACitation() async throws {
        let script = Script { _ in (200, Data(Self.recordedWork.utf8), [:]) }
        let work = try await client(script).work("W2159974629")
        XCTAssertTrue(work.citation.contains("Kucsko G"), work.citation)
        XCTAssertTrue(work.citation.contains("(2013)"), work.citation)
        XCTAssertTrue(work.citation.contains("Nature 500(7460):54-58"), work.citation)
        XCTAssertFalse(work.citation.contains(".."), "the join supplies the stop")
    }

    func testPageDecodesCountAndCursorFromMeta() async throws {
        let script = Script { _ in (200, Data(Self.recordedPage.utf8), [:]) }
        let page = try await client(script).works(matching: "crispr")
        XCTAssertEqual(page.count, 372791)
        XCTAssertEqual(page.nextCursor, "NEXT")
        XCTAssertEqual(page.results.count, 1)
    }

    // MARK: - Citation direction

    func testCitedByAndReferencesUseOppositeFiltersAndDoNotRelookUpAKey() async throws {
        let script = Script { _ in (200, Data(Self.recordedPage.utf8), [:]) }
        _ = try await client(script).citedBy("W2159974629")
        _ = try await client(script).references(of: "W2159974629")

        XCTAssertEqual(script.count, 2, "a bare key needs no resolving round trip")
        XCTAssertTrue(script.urls[0].contains("filter=cites:W2159974629"), script.urls[0])
        XCTAssertTrue(script.urls[1].contains("filter=cited_by:W2159974629"), script.urls[1])
    }

    func testADOIIsResolvedToAKeyBeforeAFilterIsBuilt() async throws {
        let script = Script { request in
            request.url!.absoluteString.contains("/works/doi:")
                ? (200, Data(Self.recordedWork.utf8), [:])
                : (200, Data(Self.recordedPage.utf8), [:])
        }
        _ = try await client(script).citedBy("10.1038/nature12373")
        XCTAssertEqual(script.count, 2, "one lookup to learn the key, one to filter")
        XCTAssertTrue(script.urls[0].contains("/works/doi:10.1038/nature12373"))
        XCTAssertTrue(script.urls[1].contains("filter=cites:W2159974629"))
    }

    // MARK: - Requests

    func testPerPageIsClampedRatherThanLettingTheAPI400() async throws {
        let script = Script { _ in (200, Data(Self.recordedPage.utf8), [:]) }
        _ = try await client(script).works(matching: "x", perPage: 5000)
        XCTAssertTrue(script.urls[0].contains("per-page=200"), script.urls[0])
        _ = try await client(script).works(matching: "x", perPage: 0)
        XCTAssertTrue(script.urls[1].contains("per-page=1"), script.urls[1])
    }

    func testTheMailtoAndUserAgentTravelWithEveryRequest() async throws {
        let script = Script { _ in (200, Data(Self.recordedWork.utf8), [:]) }
        _ = try await client(script).work("W2159974629")
        let request = try XCTUnwrap(script.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), OpenAlex.defaultUserAgent)
        XCTAssertTrue(request.url!.absoluteString.contains("mailto=test@example.com"))
    }

    // MARK: - Failures

    func testAStoppedQueryIsRetriedBecauseItIsMeasurablyTransient() async throws {
        let body = #"{"error":"Gateway timeout","message":"too broad","reason":"query_timeout"}"#
        let calls = Counter()
        let script = Script { _ in
            calls.bump() == 1 ? (504, Data(body.utf8), [:]) : (200, Data(Self.recordedPage.utf8), [:])
        }
        let page = try await client(script).works(matching: "crispr")
        XCTAssertEqual(page.count, 372791, "the retry should have succeeded")
        XCTAssertEqual(script.count, 2, "one failure, one retry")
    }

    func testAStoppedQuerySurfacesOnceTheRetriesAreSpent() async {
        let body = #"{"error":"Gateway timeout","message":"too broad","reason":"query_timeout"}"#
        let script = Script { _ in (504, Data(body.utf8), [:]) }
        do {
            _ = try await client(script).works(matching: "everything")
            XCTFail("expected queryStopped")
        } catch {
            XCTAssertEqual(error as? OpenAlexError, .queryStopped("too broad"))
        }
        XCTAssertEqual(script.count, 3, "the first attempt plus two retries")
    }

    /// A call counter safe to touch from the transport closure.
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        /// Increments and returns the new count.
        func bump() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
    }

    func testAPlainServerErrorStaysAnHTTPError() async {
        let script = Script { _ in (503, Data("nope".utf8), [:]) }
        do {
            _ = try await client(script).works(matching: "x")
            XCTFail("expected http")
        } catch {
            XCTAssertEqual(error as? OpenAlexError, .http(503))
        }
    }

    func testRateLimitRetriesThenGivesUp() async {
        let script = Script { _ in (429, Data(), ["Retry-After": "2"]) }
        do {
            _ = try await client(script).work("W1")
            XCTFail("expected rateLimited")
        } catch {
            XCTAssertEqual(error as? OpenAlexError, .rateLimited(retryAfter: 2))
        }
        XCTAssertEqual(script.count, 3, "the first attempt plus two retries")
    }
}

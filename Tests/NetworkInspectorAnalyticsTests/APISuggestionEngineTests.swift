import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorAnalytics

final class APISuggestionEngineTests: XCTestCase {

    func testDetectsGetWithBodyAntiPattern() {
        let url = URL(string: "https://api.example.com/v1/users")!
        let bodyData = "{\"filter\":\"active\"}".data(using: .utf8)!
        let req = NetworkRequest(url: url, method: "GET", headers: ["Content-Type": "application/json"], body: bodyData, rawBody: bodyData)
        let tx = NetworkTransaction(request: req)

        let report = APISuggestionEngine.analyze(transaction: tx)

        let found = report.spottedMistakes.contains { $0.title.contains("GET Request Contains Payload Body") }
        XCTAssertTrue(found, "Must detect GET request with payload body as an error")
        XCTAssertTrue(report.overallScore < 100, "Score should deduct for GET body anti-pattern")
        XCTAssertEqual(report.suggestedRequest.method, "POST", "Suggested method should be POST for body payload")
    }

    func testDetects200OkWithErrorPayloadAntiPattern() {
        let url = URL(string: "https://api.example.com/v1/auth/login")!
        let req = NetworkRequest(url: url, method: "POST", headers: ["Content-Type": "application/json"])
        let resBody = "{\"success\": false, \"error\": \"Invalid credentials\", \"code\": 401}".data(using: .utf8)
        let res = NetworkResponse(statusCode: 200, headers: ["Content-Type": "application/json"], body: resBody)
        let tx = NetworkTransaction(request: req, response: res, status: .success)

        let report = APISuggestionEngine.analyze(transaction: tx)

        let found = report.spottedMistakes.contains { $0.title.contains("HTTP 200 OK with Error Payload") }
        XCTAssertTrue(found, "Must detect 200 OK returned with error payload")
        XCTAssertEqual(report.suggestedResponse.statusCode, 400, "Suggested status should be 4xx instead of 200")
        XCTAssertTrue(report.suggestedResponse.headers["Content-Type"]?.contains("problem+json") == true)
    }

    func testDetectsVerbInRestPathAndNonStandardCasing() {
        let url = URL(string: "https://api.example.com/api/v1/getUser_profile/")!
        let req = NetworkRequest(url: url, method: "GET", headers: ["Accept": "application/json"])
        let tx = NetworkTransaction(request: req)

        let report = APISuggestionEngine.analyze(transaction: tx)

        let foundVerb = report.spottedMistakes.contains { $0.category == .restDesign && $0.title.contains("Action Verb") }
        let foundTrailing = report.spottedMistakes.contains { $0.title.contains("Trailing Slash") }
        let foundCasing = report.spottedMistakes.contains { $0.title.contains("Non-Standard Path Casing") }

        XCTAssertTrue(foundVerb, "Must flag action verbs in REST path")
        XCTAssertTrue(foundTrailing, "Must flag trailing slash in REST path")
        XCTAssertTrue(foundCasing, "Must flag snake_case/camelCase in path segments")
        XCTAssertFalse(report.suggestedRequest.url.hasSuffix("/"), "Suggested URL must not end with trailing slash")
    }

    func testDetectsLeakedCredentialsInQueryString() {
        let url = URL(string: "https://api.example.com/v1/events?apiKey=secret_key_12345&organizer_id=abc")!
        let req = NetworkRequest(url: url, method: "GET", headers: [:])
        let tx = NetworkTransaction(request: req)

        let report = APISuggestionEngine.analyze(transaction: tx)

        let foundCredential = report.spottedMistakes.contains { $0.category == .security && $0.title.contains("Credential Passed in Query Parameter") }
        XCTAssertTrue(foundCredential, "Must detect sensitive API key passed in query string")

        // In suggested request, apiKey should be stripped from query and moved to Authorization header
        XCTAssertFalse(report.suggestedRequest.url.contains("apiKey=secret"), "Suggested URL must strip credentials from query")
        XCTAssertTrue(report.suggestedRequest.headers["Authorization"]?.contains("secret_key_12345") == true, "Suggested request must add Authorization header")
    }

    func testDetectsMissingHeaders() {
        let url = URL(string: "https://api.example.com/v1/items")!
        let bodyData = "{\"title\":\"Item 1\"}".data(using: .utf8)!
        // Missing Accept and Content-Type
        let req = NetworkRequest(url: url, method: "POST", headers: [:], body: bodyData, rawBody: bodyData)
        let tx = NetworkTransaction(request: req)

        let report = APISuggestionEngine.analyze(transaction: tx)

        let missingAccept = report.spottedMistakes.contains { $0.title.contains("Missing `Accept` Header") }
        let missingContentType = report.spottedMistakes.contains { $0.title.contains("Missing `Content-Type` Header") }

        XCTAssertTrue(missingAccept, "Must flag missing Accept header")
        XCTAssertTrue(missingContentType, "Must flag missing Content-Type header on request with body")

        XCTAssertEqual(report.suggestedRequest.headers["Accept"], "application/json")
        XCTAssertEqual(report.suggestedRequest.headers["Content-Type"], "application/json")
    }

    func testDetects204WithBodyViolation() {
        let url = URL(string: "https://api.example.com/v1/items/42")!
        let req = NetworkRequest(url: url, method: "DELETE", headers: [:])
        let resBody = "{\"status\": \"deleted\"}".data(using: .utf8)
        let res = NetworkResponse(statusCode: 204, headers: ["Content-Type": "application/json"], body: resBody)
        let tx = NetworkTransaction(request: req, response: res, status: .success)

        let report = APISuggestionEngine.analyze(transaction: tx)

        let found204Violation = report.spottedMistakes.contains { $0.title.contains("HTTP 204 No Content with Message Body") }
        XCTAssertTrue(found204Violation, "Must flag RFC 9110 violation for 204 with body")
        XCTAssertNil(report.suggestedResponse.body, "Suggested response for 204 must have nil body")
    }

    func testCleanRequestGivesGradeAPlus() {
        let url = URL(string: "https://api.example.com/v1/users/42")!
        let headers = [
            "Accept": "application/json",
            "Authorization": "Bearer valid_jwt_token",
            "User-Agent": "App/1.0 (iOS 17.0)"
        ]
        let req = NetworkRequest(url: url, method: "GET", headers: headers, rawHeaders: headers)
        let resBody = "{\"id\": 42, \"name\": \"Bob\"}".data(using: .utf8)
        let res = NetworkResponse(statusCode: 200, headers: ["Content-Type": "application/json", "Cache-Control": "max-age=3600"], body: resBody)
        let tx = NetworkTransaction(request: req, response: res, duration: 0.12, status: .success)

        let report = APISuggestionEngine.analyze(transaction: tx)

        XCTAssertEqual(report.overallScore, 100)
        XCTAssertEqual(report.grade, "A+")
        XCTAssertTrue(report.spottedMistakes.isEmpty)
    }
}


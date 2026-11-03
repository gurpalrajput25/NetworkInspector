import XCTest
import NetworkInspectorCore
import NetworkInspectorAnalytics
@testable import NetworkInspectorIntegrations

final class TeamsNotificationBuilderTests: XCTestCase {

    func testAdaptiveCardStructureWithCodeBlocks() {
        let url = URL(string: "https://qa-events.venivibe.com/events/organized-events?dateFrom=2026-11-02&order=ASC&orderBy=event_start_time&organizer_id=e3413b1b-1166-489f-923d-30ca368bc51a&search=&type=1")!
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoINGRlZjhkNjUtODQwNi00ZGQ4LTkwZmYtY2FlYTNjMWMxYzk0In0.signature"
        let headers = [
            "Time-Zone": "Asia/Kolkata",
            "Authorization": "Bearer \(token)"
        ]

        let request = NetworkRequest(url: url, method: "GET", headers: headers, rawHeaders: headers)
        let transaction = NetworkTransaction(request: request)

        // Build Adaptive Card with Live Token (unmasked)
        let card = TeamsNotificationBuilder.buildAdaptiveCard(
            transaction: transaction,
            developerNote: "QA Verification Note",
            environmentName: "QA",
            maskTokens: false
        )

        XCTAssertEqual(card["type"] as? String, "AdaptiveCard")
        XCTAssertEqual(card["version"] as? String, "1.5")

        // Assert Open in Postman is not in actions
        if let actions = card["actions"] as? [[String: Any]] {
            for action in actions {
                let title = action["title"] as? String ?? ""
                XCTAssertFalse(title.contains("Postman"), "Adaptive Card actions must NOT contain Open in Postman")
            }
        }

        guard let body = card["body"] as? [[String: Any]] else {
            XCTFail("Missing body array in Adaptive Card")
            return
        }

        // Find Container with CodeBlock items
        var foundSingleLineCodeBlock = false
        var foundMultiLineCodeBlock = false

        for item in body {
            if let containerItems = item["items"] as? [[String: Any]] {
                for sub in containerItems {
                    if sub["type"] as? String == "CodeBlock" {
                        let snippet = sub["codeSnippet"] as? String ?? ""
                        if !snippet.contains("\n") {
                            foundSingleLineCodeBlock = true
                            // Verify single line format
                            XCTAssertTrue(snippet.hasPrefix("curl --location 'https://qa-events.venivibe.com/events/organized-events?"))
                            XCTAssertFalse(snippet.contains("-X GET"))
                            XCTAssertTrue(snippet.contains(token))
                            XCTAssertTrue(snippet.contains("--header 'Time-Zone: Asia/Kolkata'"))

                            // Verify fallback does not contain bash tag and has wrap: false
                            if let fallback = sub["fallback"] as? [String: Any] {
                                XCTAssertEqual(fallback["type"] as? String, "TextBlock")
                                XCTAssertEqual(fallback["wrap"] as? Bool, false)
                                let fallbackText = fallback["text"] as? String ?? ""
                                XCTAssertFalse(fallbackText.contains("```bash"))
                                XCTAssertTrue(fallbackText.hasPrefix("```\ncurl"))
                            } else {
                                XCTFail("Single-line CodeBlock missing fallback")
                            }
                        } else {
                            foundMultiLineCodeBlock = true
                            XCTAssertTrue(snippet.contains(" \\\n  --header '"))
                            XCTAssertTrue(snippet.contains(token))
                        }
                    }
                }
            }
        }

        XCTAssertTrue(foundSingleLineCodeBlock, "Adaptive Card must include 1-line CodeBlock for direct execution")
        XCTAssertTrue(foundMultiLineCodeBlock, "Adaptive Card must include multi-line CodeBlock for terminal inspection")
    }

    func testAdaptiveCardWithRequestBodyAndServerResponsePeek() {
        let url = URL(string: "https://api.example.com/v1/checkout")!
        let reqBody = "{\"cart_id\":\"12345\",\"amount\":99.9}".data(using: .utf8)
        let req = NetworkRequest(url: url, method: "POST", headers: ["Content-Type": "application/json"], body: reqBody, rawBody: reqBody)

        let resBody = "{\"status\":500,\"error\":\"PaymentGatewayTimeout\",\"message\":\"Stripe did not respond\"}".data(using: .utf8)
        let res = NetworkResponse(statusCode: 500, headers: ["Content-Type": "application/json"], body: resBody)

        let tx = NetworkTransaction(request: req, response: res, status: .failed)

        let card = TeamsNotificationBuilder.buildAdaptiveCard(transaction: tx, environmentName: "Production")
        guard let body = card["body"] as? [[String: Any]] else {
            XCTFail("Missing body")
            return
        }

        var foundReqPayloadPeek = false
        var foundServerErrorPeek = false

        for item in body {
            if let containerItems = item["items"] as? [[String: Any]] {
                for sub in containerItems {
                    if let text = sub["text"] as? String {
                        if text.contains("Request Body") {
                            foundReqPayloadPeek = true
                        }
                        if text.contains("Server Error Response (500") {
                            foundServerErrorPeek = true
                        }
                    }
                }
            }
        }

        XCTAssertTrue(foundReqPayloadPeek, "Adaptive card must include request payload peek for backend inspection")
        XCTAssertTrue(foundServerErrorPeek, "Adaptive card must include server error response peek for fast debugging")
    }

    func testAdaptiveCardMessagePayloadWithAISuggestionsAndAnalytics() {
        let url = URL(string: "https://api.example.com/api/deleteUser?apiKey=secret_xyz")!
        let reqBody = "{\"user\":\"123\"}".data(using: .utf8)
        let req = NetworkRequest(url: url, method: "GET", headers: [:], body: reqBody, rawBody: reqBody)
        let resBody = "{\"success\": false, \"error\": \"User not found\"}".data(using: .utf8)
        let res = NetworkResponse(statusCode: 200, headers: ["Content-Type": "application/json"], body: resBody)

        let tx = NetworkTransaction(request: req, response: res, status: .success)

        let message = TeamsNotificationBuilder.buildMessagePayload(
            transaction: tx,
            developerNote: "Developer Review",
            includeAISuggestions: true,
            includeAnalytics: true
        )

        XCTAssertEqual(message["type"] as? String, "message")
        guard let attachments = message["attachments"] as? [[String: Any]],
              let first = attachments.first,
              let card = first["content"] as? [String: Any],
              let body = card["body"] as? [[String: Any]] else {
            XCTFail("Missing message card content")
            return
        }

        var foundAISuggestions = false
        var foundAnalytics = false

        for item in body {
            if let containerItems = item["items"] as? [[String: Any]] {
                for sub in containerItems {
                    let text = sub["text"] as? String ?? ""
                    if text.contains("AI Suggestions & API Standards Audit") {
                        foundAISuggestions = true
                    }
                    if text.contains("Request Analytics & Waterfall Timings") {
                        foundAnalytics = true
                    }
                }
            }
        }

        XCTAssertTrue(foundAISuggestions, "Message envelope must contain AI Suggestions section")
        XCTAssertTrue(foundAnalytics, "Message envelope must contain Request Analytics section")
    }
}

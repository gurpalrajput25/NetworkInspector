import XCTest
import NetworkInspectorCore
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

        XCTAssertTrue(foundSingleLineCodeBlock, "Adaptive Card must include 1-line CodeBlock for 1-click Postman import")
        XCTAssertTrue(foundMultiLineCodeBlock, "Adaptive Card must include multi-line CodeBlock for terminal inspection")
    }
}

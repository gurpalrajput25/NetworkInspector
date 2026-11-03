import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorIntegrations

final class TeamsAdaptiveCardBuilderTests: XCTestCase {

    func testAdaptiveCardBuilderPayloadContract() {
        let curl = "curl -X GET 'https://qa-events.venivibe.com/events' \\\n  -H 'Authorization: Bearer token'"
        let diagnostics = TeamsAdaptiveCardBuilder.DeviceDiagnostics(
            model: "arm64",
            osVersion: "iOS 27.0",
            appVersion: "VeniVibe Vendor v1.5.2 (1)",
            timezone: "Asia/Kolkata",
            locale: "en_IN"
        )
        let deepLink = "https://go.postman.co/workspace/ws-12345/request/req-67890"
        let note = "Tested attendee lookup under organizer UUID scope."

        let payload = TeamsAdaptiveCardBuilder.buildPayload(
            curlString: curl,
            diagnostics: diagnostics,
            postmanDeepLink: deepLink,
            developerNote: note
        )

        // Top-level message envelope
        XCTAssertEqual(payload["type"] as? String, "message")
        guard let attachments = payload["attachments"] as? [[String: Any]],
              let first = attachments.first else {
            XCTFail("Missing attachments")
            return
        }

        XCTAssertEqual(first["contentType"] as? String, "application/vnd.microsoft.card.adaptive")
        guard let content = first["content"] as? [String: Any] else {
            XCTFail("Missing content")
            return
        }

        XCTAssertEqual(content["type"] as? String, "AdaptiveCard")
        XCTAssertEqual(content["version"] as? String, "1.4")
        XCTAssertEqual(content["$schema"] as? String, "http://adaptivecards.io/schemas/adaptive-card.json")

        // Actions array verification
        guard let actions = content["actions"] as? [[String: Any]],
              let openAction = actions.first else {
            XCTFail("Missing Action.OpenUrl action")
            return
        }

        XCTAssertEqual(openAction["type"] as? String, "Action.OpenUrl")
        XCTAssertEqual(openAction["title"] as? String, "🚀 Open in Postman")
        XCTAssertEqual(openAction["url"] as? String, deepLink)

        // Monospace Code Fence container verification
        guard let body = content["body"] as? [[String: Any]] else {
            XCTFail("Missing body")
            return
        }

        var foundContainer = false
        var foundCodeFence = false

        for element in body {
            if element["type"] as? String == "Container",
               element["style"] as? String == "emphasis",
               element["bleed"] as? Bool == true {
                foundContainer = true
                if let items = element["items"] as? [[String: Any]],
                   let codeBlock = items.first {
                    XCTAssertEqual(codeBlock["fontType"] as? String, "Monospace")
                    let text = codeBlock["text"] as? String ?? ""
                    if text.contains("```bash\ncurl") {
                        foundCodeFence = true
                    }
                }
            }
        }

        XCTAssertTrue(foundContainer, "Must have emphasis bleed container")
        XCTAssertTrue(foundCodeFence, "Must contain code fence with ```bash")
    }

    func testAdaptiveCardWithoutDeepLink() {
        let curl = "curl -X GET 'https://api.example.com'"
        let diagnostics = TeamsAdaptiveCardBuilder.DeviceDiagnostics.current()

        let payload = TeamsAdaptiveCardBuilder.buildPayload(
            curlString: curl,
            diagnostics: diagnostics,
            postmanDeepLink: nil,
            developerNote: nil
        )

        guard let attachments = payload["attachments"] as? [[String: Any]],
              let content = attachments.first?["content"] as? [String: Any],
              let actions = content["actions"] as? [[String: Any]] else {
            XCTFail("Malformed payload")
            return
        }

        XCTAssertTrue(actions.isEmpty, "Actions should be empty when postmanDeepLink is nil")
    }

    func testAdaptiveCardWithAuthenticatedUserAndQueryOrg() {
        let url = URL(string: "https://qa-events.venivibe.com/events/organized-events?organizer_id=e3413b1b-1166-489f-923d-30ca368bc51a")!
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiNGRlZjhkNjUtODQwNi00ZGQ4LTkwZmYtY2FlYTNjMWMxYzk0In0.signature"
        let headers = ["Authorization": "Bearer \(token)"]
        let req = NetworkRequest(url: url, method: "GET", headers: headers, rawHeaders: headers)
        let tx = NetworkTransaction(request: req)

        let payload = TeamsAdaptiveCardBuilder.buildPayload(transaction: tx)
        guard let attachments = payload["attachments"] as? [[String: Any]],
              let content = attachments.first?["content"] as? [String: Any],
              let body = content["body"] as? [[String: Any]] else {
            XCTFail("Malformed payload")
            return
        }

        var foundUserFactSet = false
        for item in body {
            if let facts = item["facts"] as? [[String: String]] {
                let keys = facts.compactMap { $0["title"] }
                if keys.contains("User ID:") && keys.contains("Organizer ID:") {
                    foundUserFactSet = true
                    let userVal = facts.first(where: { $0["title"] == "User ID:" })?["value"]
                    let orgVal = facts.first(where: { $0["title"] == "Organizer ID:" })?["value"]
                    XCTAssertEqual(userVal, "4def8d65-8406-4dd8-90ff-caea3c1c1c94")
                    XCTAssertEqual(orgVal, "e3413b1b-1166-489f-923d-30ca368bc51a")
                }
            }
        }

        XCTAssertTrue(foundUserFactSet, "Card must include Authenticated User Details with User ID and Organizer ID")
    }
}

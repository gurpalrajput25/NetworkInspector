import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorIntegrations

final class PostmanLinkBuilderTests: XCTestCase {

    func testBuildImportLinkWithCurlString() {
        let curl = "curl -X GET 'https://qa-events.venivibe.com/events' -H 'Authorization: Bearer test_token'"
        let link = PostmanLinkBuilder.buildImportLink(curlString: curl)

        XCTAssertTrue(link.hasPrefix("https://gurpalrajput25.github.io/NetworkInspector/import.html#data="))

        // Verify base64url payload decodes cleanly
        let hash = link.components(separatedBy: "#data=").last ?? ""
        var base64 = hash.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to decode base64 payload from link")
            return
        }

        XCTAssertEqual(json["curl"] as? String, curl)
    }

    func testBuildImportLinkWithNetworkTransaction() {
        let url = URL(string: "https://api.example.com/items?id=123")!
        let req = NetworkRequest(url: url, method: "POST", headers: ["Content-Type": "application/json"], body: "{\"name\":\"test\"}".data(using: .utf8))
        let tx = NetworkTransaction(request: req)

        let link = PostmanLinkBuilder.buildImportLink(
            curlString: "curl -X POST 'https://api.example.com/items?id=123' --data '{\"name\":\"test\"}'",
            transaction: tx
        )

        XCTAssertTrue(link.contains("import.html#data="))
        let hash = link.components(separatedBy: "#data=").last ?? ""
        var base64 = hash.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to decode base64 payload")
            return
        }

        XCTAssertEqual(json["method"] as? String, "POST")
        XCTAssertEqual(json["url"] as? String, "https://api.example.com/items?id=123")
        XCTAssertEqual(json["body"] as? String, "{\"name\":\"test\"}")
    }
}

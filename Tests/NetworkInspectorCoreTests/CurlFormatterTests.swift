import XCTest
import NetworkInspectorCore

final class CurlFormatterTests: XCTestCase {

    func testCurlFormatterWithURLRequest() {
        let url = URL(string: "https://qa-events.venivibe.com/events/organized-events?dateFrom=2026-11-02&order=ASC&orderBy=event_start_time&organizer_id=e3413b1b-1166-489f-923d-30ca368bc51a&search=&type=1")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Asia/Kolkata", forHTTPHeaderField: "Time-Zone")
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.SIGNATURE", forHTTPHeaderField: "Authorization")

        let formatted = CurlFormatter.format(request: request)

        XCTAssertTrue(formatted.contains("curl -X GET 'https://qa-events.venivibe.com/events/organized-events?"))
        XCTAssertTrue(formatted.contains(" \\\n  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.SIGNATURE'"))
        XCTAssertTrue(formatted.contains(" \\\n  -H 'Time-Zone: Asia/Kolkata'"))
    }

    func testCurlFormatterWithBodyAndEscaping() {
        let url = URL(string: "https://api.example.com/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"title\":\"It's a party\"}".data(using: .utf8)

        let formatted = CurlFormatter.format(request: request)

        XCTAssertTrue(formatted.hasPrefix("curl -X POST 'https://api.example.com/events'"))
        XCTAssertTrue(formatted.contains(" \\\n  -H 'Content-Type: application/json'"))
        XCTAssertTrue(formatted.contains(" \\\n  --data '{\"title\":\"It'\\''s a party\"}'"))
    }

    func testCurlFormatterWithNetworkTransaction() {
        let url = URL(string: "https://api.example.com/items")!
        let req = NetworkRequest(url: url, method: "POST", headers: ["X-Api-Key": "secret"], body: "{}".data(using: .utf8))
        let tx = NetworkTransaction(request: req)

        let formatted = CurlFormatter.format(transaction: tx)
        XCTAssertTrue(formatted.contains("curl -X POST 'https://api.example.com/items'"))
        XCTAssertTrue(formatted.contains("-H 'X-Api-Key: secret'"))
        XCTAssertTrue(formatted.contains("--data '{}'"))
    }
}

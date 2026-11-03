import XCTest
@testable import NetworkInspectorCore

final class NetworkRequestTests: XCTestCase {

    func testNetworkRequestInitialization() {
        let url = URL(string: "https://api.example.com/v1/users?page=1&limit=20")!
        let bodyData = "{\"name\":\"test\"}".data(using: .utf8)
        let headers = ["Content-Type": "application/json", "Accept": "application/json"]

        let request = NetworkRequest(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData
        )

        XCTAssertEqual(request.host, "api.example.com")
        XCTAssertEqual(request.path, "/v1/users")
        XCTAssertEqual(request.queryItems["page"], "1")
        XCTAssertEqual(request.queryItems["limit"], "20")
        XCTAssertEqual(request.method, .post)
        XCTAssertTrue(request.isJSON)
        XCTAssertFalse(request.isMultipart)
        XCTAssertEqual(request.bodyString, "{\"name\":\"test\"}")
    }

    func testCurlGeneration() {
        let url = URL(string: "https://api.example.com/login")!
        let headers = ["Authorization": "Bearer secret_token_12345", "Content-Type": "application/json"]
        let request = NetworkRequest(url: url, method: "POST", headers: headers, body: "{\"user\":\"admin\"}".data(using: .utf8))

        let transaction = NetworkTransaction(request: request)
        let curlMasked = transaction.generateCurl(maskTokens: true)

        XCTAssertTrue(curlMasked.contains("curl --location --request POST 'https://api.example.com/login'"))
        XCTAssertFalse(curlMasked.contains("secret_token_12345"))
        XCTAssertTrue(curlMasked.contains("Bearer"))

        // Unmasked Live Token (for direct Postman execution)
        let curlLive = transaction.generateCurl(maskTokens: false)
        XCTAssertTrue(curlLive.contains("Bearer secret_token_12345"), "Live cURL must contain the exact live token for direct Postman import")
        XCTAssertTrue(curlLive.contains("--data-raw '{\"user\":\"admin\"}'"))

        // Single-line cURL (for 1-click Postman import with no line breaks)
        let curlSingleLine = transaction.generateCurl(maskTokens: false, singleLine: true)
        XCTAssertFalse(curlSingleLine.contains("\n"), "Single-line cURL must have zero newlines")
        XCTAssertTrue(curlSingleLine.contains("Bearer secret_token_12345"))
        XCTAssertTrue(curlSingleLine.hasPrefix("curl --location --request POST 'https://api.example.com/login'"))

        // GET request cURL (omits -X GET for clean Postman address bar and import compatibility)
        let getUrl = URL(string: "https://api.example.com/events?date=2026-11-03&type=1")!
        let getReq = NetworkRequest(url: getUrl, method: "GET", headers: ["Authorization": "Bearer token123"])
        let getTx = NetworkTransaction(request: getReq)
        let getCurl = getTx.generateCurl(maskTokens: false, singleLine: true)
        XCTAssertTrue(getCurl.hasPrefix("curl --location 'https://api.example.com/events?date=2026-11-03&type=1'"))
        XCTAssertFalse(getCurl.contains("-X GET"), "GET requests should omit -X GET for Postman importer compatibility")
        XCTAssertTrue(getCurl.contains("--header 'Authorization: Bearer token123'"))
    }
}


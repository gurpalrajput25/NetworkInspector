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
        let request = NetworkRequest(url: url, method: "POST", headers: headers, body: "{}".data(using: .utf8))

        let transaction = NetworkTransaction(request: request)
        let curlMasked = transaction.generateCurl(maskTokens: true)

        XCTAssertTrue(curlMasked.contains("curl -X POST 'https://api.example.com/login'"))
        XCTAssertFalse(curlMasked.contains("secret_token_12345"))
        XCTAssertTrue(curlMasked.contains("Bearer"))

        // Unmasked Live Token (for direct Postman execution)
        let curlLive = transaction.generateCurl(maskTokens: false)
        XCTAssertTrue(curlLive.contains("Bearer secret_token_12345"), "Live cURL must contain the exact live token for direct Postman import")
    }
}


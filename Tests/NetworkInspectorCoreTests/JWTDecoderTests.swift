import XCTest
@testable import NetworkInspectorCore

final class JWTDecoderTests: XCTestCase {

    func testJWTDecoding() {
        // Sample JWT payload: {"sub":"usr_998877","email":"developer@venivibe.com","name":"John Doe","role":"vendor_admin","exp":1893456000}
        // Base64URL header: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
        // Base64URL payload: eyJzdWIiOiJ1c3JfOTk4ODc3IiwiZW1haWwiOiJkZXZlbG9wZXJAdmVuaXZpYmUuY29tIiwibmFtZSI6IkpvaG4gRG9lIiwicm9sZSI6InZlbmRvcl9hZG1pbiIsImV4cCI6MTg5MzQ1NjAwMH0
        let token = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfOTk4ODc3IiwiZW1haWwiOiJkZXZlbG9wZXJAdmVuaXZpYmUuY29tIiwibmFtZSI6IkpvaG4gRG9lIiwicm9sZSI6InZlbmRvcl9hZG1pbiIsImV4cCI6MTg5MzQ1NjAwMH0.mock_signature"

        let userDetails = JWTDecoder.decode(jwt: token)
        XCTAssertNotNil(userDetails)
        XCTAssertEqual(userDetails?.userId, "usr_998877")
        XCTAssertEqual(userDetails?.email, "developer@venivibe.com")
        XCTAssertEqual(userDetails?.name, "John Doe")
        XCTAssertEqual(userDetails?.role, "vendor_admin")
        XCTAssertFalse(userDetails?.isExpired ?? true)
    }

    func testJWTExtractionFromHeaders() {
        let headers = [
            "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfMTIzIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIn0.signature"
        ]
        let userDetails = JWTDecoder.extractFromHeaders(headers)
        XCTAssertNotNil(userDetails)
        XCTAssertEqual(userDetails?.userId, "usr_123")
        XCTAssertEqual(userDetails?.email, "test@example.com")
    }

    func testJWTExtractionFromResponseBody() {
        // {"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfNDU2IiwiZW1haWwiOiJsb2dpbkBleGFtcGxlLmNvbSIsIm5hbWUiOiJBbGljZSBTbWl0aCJ9.signature"}
        let jsonResponse = """
        {
            "status": "success",
            "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfNDU2IiwiZW1haWwiOiJsb2dpbkBleGFtcGxlLmNvbSIsIm5hbWUiOiJBbGljZSBTbWl0aCJ9.signature"
        }
        """.data(using: .utf8)!

        let userDetails = JWTDecoder.extractFromResponseBody(jsonResponse)
        XCTAssertNotNil(userDetails)
        XCTAssertEqual(userDetails?.userId, "usr_456")
        XCTAssertEqual(userDetails?.email, "login@example.com")
        XCTAssertEqual(userDetails?.name, "Alice Smith")
    }

    func testJWTWithNumericSubAndTokenPrefix() {
        // Payload: {"sub":9999,"preferred_username":"guru@example.com","display_name":"Guru"}
        // eyJzdWIiOjk5OTksInByZWZlcnJlZF91c2VybmFtZSI6Imd1cnVAZXhhbXBsZS5jb20iLCJkaXNwbGF5X25hbWUiOiJHdXJ1In0
        let token = "Token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjk5OTksInByZWZlcnJlZF91c2VybmFtZSI6Imd1cnVAZXhhbXBsZS5jb20iLCJkaXNwbGF5X25hbWUiOiJHdXJ1In0.sig"
        let user = JWTDecoder.decode(jwt: token)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "9999")
        XCTAssertEqual(user?.email, "guru@example.com")
        XCTAssertEqual(user?.name, "Guru")
    }
}


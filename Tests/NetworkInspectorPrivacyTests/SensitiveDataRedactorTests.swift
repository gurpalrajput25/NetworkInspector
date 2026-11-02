import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorPrivacy

final class SensitiveDataRedactorTests: XCTestCase {

    func testHeaderRedaction() {
        let redactor = SensitiveDataRedactor()
        let headers = [
            "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
            "Cookie": "session=xyz123abc456",
            "Content-Type": "application/json",
            "X-Custom-Header": "AllowedValue"
        ]

        let redacted = redactor.redactHeaders(headers)

        XCTAssertNotEqual(redacted["Authorization"], "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
        XCTAssertTrue(redacted["Authorization"]?.contains("••••••••") == true || redacted["Authorization"] == "[REDACTED]")
        XCTAssertEqual(redacted["Content-Type"], "application/json")
        XCTAssertEqual(redacted["X-Custom-Header"], "AllowedValue")
    }

    func testBodyFieldRedaction() {
        let redactor = SensitiveDataRedactor()
        let json = """
        {
            "username": "user123",
            "password": "MySuperSecretPassword",
            "token": "secret_jwt_token",
            "profile": {
                "apiKey": "12345-secret"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let redactedData = redactor.redactBody(data, contentType: "application/json")

        XCTAssertNotNil(redactedData)
        let redactedString = String(data: redactedData!, encoding: .utf8)!

        XCTAssertFalse(redactedString.contains("MySuperSecretPassword"))
        XCTAssertFalse(redactedString.contains("secret_jwt_token"))
        XCTAssertFalse(redactedString.contains("12345-secret"))
        XCTAssertTrue(redactedString.contains("user123"))
    }
}


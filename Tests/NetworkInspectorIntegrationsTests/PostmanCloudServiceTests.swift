import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorIntegrations

final class MockPostmanURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockPostmanURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockError", code: -1))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class PostmanCloudServiceTests: XCTestCase {

    func testExportRequestSuccessAndDeepLink() {
        let expectation = expectation(description: "Postman Cloud export")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockPostmanURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let service = PostmanCloudService(
            apiKey: "PMAK-mock-api-key",
            collectionUid: "col-12345",
            workspaceId: "ws-67890",
            session: mockSession
        )

        MockPostmanURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.getpostman.com/collections/col-12345/requests")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "PMAK-mock-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            let jsonResponse = """
            {
                "data": {
                    "id": "req-abc-123"
                }
            }
            """
            return (response, jsonResponse.data(using: .utf8)!)
        }

        var urlReq = URLRequest(url: URL(string: "https://api.example.com/v1/users")!)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = "{\"name\":\"Alice\"}".data(using: .utf8)

        service.exportRequest(request: urlReq) { result in
            switch result {
            case .success(let deepLink):
                XCTAssertEqual(deepLink, "https://go.postman.co/workspace/ws-67890/request/req-abc-123")
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed with error: \(error)")
            }
        }

        waitForExpectations(timeout: 2.0)
    }
}


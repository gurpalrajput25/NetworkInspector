import XCTest
import NetworkInspectorCore
import NetworkInspectorStorage
@testable import NetworkInspectorURLSession

final class URLSessionCaptureTests: XCTestCase {

    func testURLSessionConfigurationFactory() {
        let baseConfig = URLSessionConfiguration.default
        let inspectableConfig = URLSessionConfigurationFactory.makeInspectable(configuration: baseConfig)

        let containsProtocol = inspectableConfig.protocolClasses?.contains(where: { $0 == NetworkURLProtocol.self }) ?? false
        XCTAssertTrue(containsProtocol, "NetworkURLProtocol should be inserted into protocolClasses")
    }

    func testURLProtocolCanInit() {
        let httpReq = URLRequest(url: URL(string: "https://api.example.com/test")!)
        XCTAssertTrue(NetworkURLProtocol.canInit(with: httpReq))

        let nonHttpReq = URLRequest(url: URL(string: "ftp://example.com/file")!)
        XCTAssertFalse(NetworkURLProtocol.canInit(with: nonHttpReq))
    }
}


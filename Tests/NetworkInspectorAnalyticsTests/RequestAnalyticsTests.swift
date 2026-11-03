import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorAnalytics

final class RequestAnalyticsTests: XCTestCase {

    func testRequestAnalyticsBuilderComputesPhasesAndSizes() {
        let url = URL(string: "https://api.example.com/v1/orders")!
        let reqHeaders = ["Authorization": "Bearer token123", "Content-Type": "application/json"]
        let reqBody = "{\"item_id\": 99, \"quantity\": 2}".data(using: .utf8)!
        let req = NetworkRequest(url: url, method: "POST", headers: reqHeaders, rawHeaders: reqHeaders, body: reqBody, rawBody: reqBody)

        let resHeaders = [
            "Content-Type": "application/json",
            "Content-Encoding": "gzip",
            "Cache-Control": "no-cache",
            "ETag": "W/\"12345\""
        ]
        let resBody = "{\"order_id\": 1001, \"status\": \"confirmed\"}".data(using: .utf8)!
        let res = NetworkResponse(statusCode: 201, headers: resHeaders, body: resBody)

        let metrics = NetworkTaskMetrics(
            dnsDuration: 0.015,
            connectDuration: 0.025,
            tlsDuration: 0.030,
            requestDuration: 0.005,
            waitDuration: 0.120,
            responseDuration: 0.010,
            totalDuration: 0.205,
            isReusedConnection: false,
            protocolName: "h2"
        )

        let tx = NetworkTransaction(
            request: req,
            response: res,
            duration: 0.205,
            metrics: metrics,
            status: .success
        )

        let analytics = RequestAnalyticsBuilder.build(for: tx, hostAverageDuration: 0.300)

        // Verify timing and phases
        XCTAssertEqual(analytics.totalDuration, 0.205, accuracy: 0.001)
        XCTAssertEqual(analytics.dnsDuration, 0.015)
        XCTAssertEqual(analytics.connectDuration, 0.025)
        XCTAssertEqual(analytics.tlsDuration, 0.030)
        XCTAssertEqual(analytics.waitDuration, 0.120)
        XCTAssertEqual(analytics.responseDuration, 0.010)

        XCTAssertFalse(analytics.phases.isEmpty)
        let dnsPhase = analytics.phases.first(where: { $0.name == "DNS Lookup" })
        XCTAssertNotNil(dnsPhase)
        XCTAssertEqual(dnsPhase?.colorName, "purple")

        // Verify data stats
        XCTAssertEqual(analytics.requestBodyBytes, reqBody.count)
        XCTAssertEqual(analytics.responseBodyBytes, Int64(resBody.count))
        XCTAssertTrue(analytics.totalBytesSent > reqBody.count, "Total sent includes headers")
        XCTAssertTrue(analytics.totalBytesReceived > Int64(resBody.count), "Total received includes headers")
        XCTAssertTrue(analytics.totalDataTransferred > 0)

        // Verify transport & caching
        XCTAssertEqual(analytics.networkProtocol, "h2")
        XCTAssertFalse(analytics.isReusedConnection)
        XCTAssertTrue(analytics.isCompressed)
        XCTAssertEqual(analytics.contentEncoding, "gzip")
        XCTAssertNotNil(analytics.estimatedUncompressedBytes)
        XCTAssertEqual(analytics.cacheControlHeader, "no-cache")
        XCTAssertEqual(analytics.eTag, "W/\"12345\"")

        // Verify performance tier & host comparison
        XCTAssertEqual(analytics.performanceTier, .fast)
        XCTAssertNotNil(analytics.hostComparison)
        XCTAssertTrue(analytics.hostComparison?.contains("faster than host average") == true)
    }

    func testFallbackWhenMetricsAreNil() {
        let url = URL(string: "https://api.example.com/v1/ping")!
        let req = NetworkRequest(url: url, method: "GET")
        let res = NetworkResponse(statusCode: 200)
        let tx = NetworkTransaction(request: req, response: res, duration: 0.050, status: .success)

        let analytics = RequestAnalyticsBuilder.build(for: tx)

        XCTAssertEqual(analytics.totalDuration, 0.050, accuracy: 0.001)
        XCTAssertEqual(analytics.performanceTier, .blazingFast)
        XCTAssertEqual(analytics.phases.count, 1)
        XCTAssertEqual(analytics.phases.first?.name, "Round-Trip Duration")
    }
}


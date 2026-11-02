import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorAnalytics

final class NetworkAnalyticsEngineTests: XCTestCase {

    func testPercentilesAndMetrics() {
        let latencies: [TimeInterval] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

        var transactions: [NetworkTransaction] = []
        for (idx, latency) in latencies.enumerated() {
            let url = URL(string: "https://api.example.com/item/\(idx)")!
            let tx = NetworkTransaction(
                request: NetworkRequest(url: url, method: "GET"),
                response: NetworkResponse(statusCode: 200, contentLength: 1000),
                duration: latency,
                status: .success
            )
            transactions.append(tx)
        }

        let metrics = NetworkAnalyticsEngine.computeMetrics(from: transactions)

        XCTAssertEqual(metrics.totalRequests, 10)
        XCTAssertEqual(metrics.failurePercentage, 0.0)
        XCTAssertEqual(metrics.maxResponseTime, 1.0)
        XCTAssertEqual(metrics.totalDownloadedBytes, 10000)
    }

    func testHealthEvaluation() {
        let url = URL(string: "https://api.example.com/health")!
        let tx = NetworkTransaction(
            request: NetworkRequest(url: url, method: "GET"),
            response: NetworkResponse(statusCode: 200),
            duration: 0.1,
            status: .success
        )

        let report = NetworkHealthCalculator.evaluate(transactions: [tx])
        XCTAssertEqual(report.score, 100)
        XCTAssertEqual(report.status, .optimal)
    }
}


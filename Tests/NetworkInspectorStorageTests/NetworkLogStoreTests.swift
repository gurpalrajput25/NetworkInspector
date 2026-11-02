import XCTest
import NetworkInspectorCore
@testable import NetworkInspectorStorage

final class NetworkLogStoreTests: XCTestCase {

    func testRecordAndClear() {
        let store = NetworkLogStore(maxLogCount: 5)
        store.clearAll()

        XCTAssertEqual(store.transactions.count, 0)

        for i in 1...10 {
            let url = URL(string: "https://api.example.com/test/\(i)")!
            let req = NetworkRequest(url: url, method: "GET")
            let tx = NetworkTransaction(request: req)
            store.record(tx)
        }

        // Bounded to 5
        XCTAssertEqual(store.transactions.count, 5)

        // Clear all
        store.clearAll()
        XCTAssertEqual(store.transactions.count, 0)
    }

    func testLogFiltering() {
        let store = NetworkLogStore(maxLogCount: 20)
        store.clearAll()

        let url1 = URL(string: "https://api.example.com/users")!
        let tx1 = NetworkTransaction(
            request: NetworkRequest(url: url1, method: "GET"),
            response: NetworkResponse(statusCode: 200),
            status: .success
        )

        let url2 = URL(string: "https://api.example.com/auth/login")!
        let tx2 = NetworkTransaction(
            request: NetworkRequest(url: url2, method: "POST"),
            response: NetworkResponse(statusCode: 500),
            status: .failed
        )

        store.record(tx1)
        store.record(tx2)

        var filter = NetworkLogFilter()
        filter.selectedStatus = .serverError5xx
        let result = filter.apply(to: store.transactions)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.response?.statusCode, 500)
    }
}


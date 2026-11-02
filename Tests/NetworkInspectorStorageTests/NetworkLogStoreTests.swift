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

    func testCurrentUserPropagationAndPreservation() {
        let store = NetworkLogStore(maxLogCount: 10)
        store.clearAll()
        store.clearCurrentUser()

        // Transaction 1 carries Authorization JWT
        let authHeaders = [
            "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfOTk4OCIsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsIm5hbWUiOiJHdXJwYWwiLCJyb2xlIjoiYWRtaW4ifQ.sig"
        ]
        let req1 = NetworkRequest(url: URL(string: "https://api.example.com/me")!, method: "GET", headers: authHeaders)
        let tx1 = NetworkTransaction(request: req1)

        store.record(tx1)

        // Verify active currentUser was auto-populated
        XCTAssertNotNil(store.currentUser)
        XCTAssertEqual(store.currentUser?.userId, "usr_9988")
        XCTAssertEqual(store.currentUser?.email, "user@example.com")
        XCTAssertEqual(store.currentUser?.name, "Gurpal")

        // Stored transaction has user details preserved even though headers were sanitized
        let storedTx1 = store.transactions.first { $0.id == tx1.id }
        XCTAssertNotNil(storedTx1?.userDetails)
        XCTAssertEqual(storedTx1?.userDetails?.name, "Gurpal")

        // Transaction 2 has NO Authorization header (e.g. an image upload or static fetch)
        let req2 = NetworkRequest(url: URL(string: "https://api.example.com/images/1.png")!, method: "GET")
        let tx2 = NetworkTransaction(request: req2)

        store.record(tx2)

        // Verify Transaction 2 inherited the session's active logged-in user
        let storedTx2 = store.transactions.first { $0.id == tx2.id }
        XCTAssertNotNil(storedTx2?.userDetails, "Subsequent transactions should inherit the currently logged-in user")
        XCTAssertEqual(storedTx2?.userDetails?.email, "user@example.com")
    }
}


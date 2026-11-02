import Foundation
import NetworkInspectorCore

public enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case success2xx = "2xx"
    case redirect3xx = "3xx"
    case clientError4xx = "4xx"
    case serverError5xx = "5xx"
    case failed = "Failed"

    public var id: String { rawValue }
}

public struct NetworkLogFilter: Sendable {
    public var searchText: String = ""
    public var selectedMethod: HTTPMethod? = nil
    public var selectedStatus: StatusFilter = .all
    public var selectedSessionID: UUID? = nil
    public var onlyErrors: Bool = false
    public var onlyMultipart: Bool = false
    public var minDuration: TimeInterval? = nil

    public init(
        searchText: String = "",
        selectedMethod: HTTPMethod? = nil,
        selectedStatus: StatusFilter = .all,
        selectedSessionID: UUID? = nil,
        onlyErrors: Bool = false,
        onlyMultipart: Bool = false,
        minDuration: TimeInterval? = nil
    ) {
        self.searchText = searchText
        self.selectedMethod = selectedMethod
        self.selectedStatus = selectedStatus
        self.selectedSessionID = selectedSessionID
        self.onlyErrors = onlyErrors
        self.onlyMultipart = onlyMultipart
        self.minDuration = minDuration
    }

    public func matches(_ transaction: NetworkTransaction) -> Bool {
        if let sessionID = selectedSessionID, transaction.sessionID != sessionID {
            return false
        }

        if let method = selectedMethod, transaction.request.method != method {
            return false
        }

        if onlyErrors {
            let isErr = transaction.error != nil ||
                (transaction.response?.statusCode ?? 200) >= 400 ||
                transaction.status == .failed
            if !isErr { return false }
        }

        if onlyMultipart && !(transaction.request.isMultipart || (transaction.multipartParts?.isEmpty == false)) {
            return false
        }

        if let minDur = minDuration, (transaction.duration ?? 0) < minDur {
            return false
        }

        switch selectedStatus {
        case .all:
            break
        case .success2xx:
            guard let code = transaction.response?.statusCode, (200...299).contains(code) else { return false }
        case .redirect3xx:
            guard let code = transaction.response?.statusCode, (300...399).contains(code) else { return false }
        case .clientError4xx:
            guard let code = transaction.response?.statusCode, (400...499).contains(code) else { return false }
        case .serverError5xx:
            guard let code = transaction.response?.statusCode, (500...599).contains(code) else { return false }
        case .failed:
            if transaction.status != .failed && transaction.error == nil { return false }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            let urlMatch = transaction.request.url.absoluteString.lowercased().contains(query)
            let hostMatch = transaction.request.host.lowercased().contains(query)
            let pathMatch = transaction.request.path.lowercased().contains(query)
            let methodMatch = transaction.request.rawMethod.lowercased().contains(query)
            let statusMatch = String(transaction.response?.statusCode ?? 0).contains(query)

            if !urlMatch && !hostMatch && !pathMatch && !methodMatch && !statusMatch {
                return false
            }
        }

        return true
    }

    public func apply(to transactions: [NetworkTransaction]) -> [NetworkTransaction] {
        transactions.filter { matches($0) }
    }
}


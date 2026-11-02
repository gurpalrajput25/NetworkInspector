import Foundation

public enum TransactionStatus: String, Codable, Sendable {
    case pending = "Pending"
    case success = "Success"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public struct NetworkTransaction: Identifiable, Codable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let correlationID: String?
    public let clientSource: String
    public let environment: String?

    public var request: NetworkRequest
    public var response: NetworkResponse?
    public var duration: TimeInterval?
    public var error: NetworkError?
    public var metrics: NetworkTaskMetrics?
    public var multipartParts: [MultipartPart]?
    public var status: TransactionStatus

    public init(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        correlationID: String? = nil,
        clientSource: String = "URLSession",
        environment: String? = nil,
        request: NetworkRequest,
        response: NetworkResponse? = nil,
        duration: TimeInterval? = nil,
        error: NetworkError? = nil,
        metrics: NetworkTaskMetrics? = nil,
        multipartParts: [MultipartPart]? = nil,
        status: TransactionStatus = .pending
    ) {
        self.id = id
        self.sessionID = sessionID
        self.correlationID = correlationID
        self.clientSource = clientSource
        self.environment = environment
        self.request = request
        self.response = response
        self.duration = duration
        self.error = error
        self.metrics = metrics
        self.multipartParts = multipartParts
        self.status = status
    }

    public var formattedDuration: String {
        guard let d = duration else { return "—" }
        if d < 1.0 {
            return String(format: "%.0f ms", d * 1000)
        } else {
            return String(format: "%.2f s", d)
        }
    }

    public var formattedResponseSize: String {
        guard let res = response else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: res.contentLength, countStyle: .file)
    }

    public var formattedRequestSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(request.bodySize), countStyle: .file)
    }

    public func generateCurl(maskTokens: Bool = false) -> String {
        var curl = "curl -X \(request.rawMethod) '\(request.url.absoluteString)'"

        for (key, value) in request.headers {
            let headerValue: String
            if maskTokens && (key.lowercased().contains("authorization") || key.lowercased().contains("token") || key.lowercased().contains("cookie")) {
                if value.count > 16 {
                    headerValue = "\(value.prefix(6))...\(value.suffix(4))"
                } else {
                    headerValue = "[REDACTED]"
                }
            } else {
                headerValue = value
            }
            curl += " \\\n  -H '\(key): \(headerValue)'"
        }

        if let bodyString = request.bodyString, !bodyString.isEmpty {
            let escapedBody = bodyString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "'\\''")
            curl += " \\\n  --data '\(escapedBody)'"
        }

        return curl
    }
}


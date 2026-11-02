import Foundation

public struct NetworkResponse: Codable, Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data?
    public let mimeType: String?
    public let contentLength: Int64
    public let timestamp: Date

    public init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data? = nil,
        mimeType: String? = nil,
        contentLength: Int64? = nil,
        timestamp: Date = Date()
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.mimeType = mimeType
        self.contentLength = contentLength ?? Int64(body?.count ?? 0)
        self.timestamp = timestamp
    }

    public var isSuccess: Bool {
        (200...299).contains(statusCode)
    }

    public var isRedirect: Bool {
        (300...399).contains(statusCode)
    }

    public var isClientError: Bool {
        (400...499).contains(statusCode)
    }

    public var isServerError: Bool {
        (500...599).contains(statusCode)
    }

    public var bodyString: String? {
        guard let body = body, !body.isEmpty else { return nil }
        return String(data: body, encoding: .utf8)
            ?? String(data: body, encoding: .ascii)
    }

    public var statusDescription: String {
        HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    }
}


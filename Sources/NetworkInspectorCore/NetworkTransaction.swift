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
    public var userDetails: JWTUserDetails?
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
        userDetails: JWTUserDetails? = nil,
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
        self.userDetails = userDetails ?? JWTDecoder.extractFromHeaders(request.rawHeaders)
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, sessionID, correlationID, clientSource, environment, request, response, duration, error, metrics, multipartParts, userDetails, status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.sessionID = try container.decode(UUID.self, forKey: .sessionID)
        self.correlationID = try container.decodeIfPresent(String.self, forKey: .correlationID)
        self.clientSource = try container.decode(String.self, forKey: .clientSource)
        self.environment = try container.decodeIfPresent(String.self, forKey: .environment)
        let decReq = try container.decode(NetworkRequest.self, forKey: .request)
        self.request = decReq
        self.response = try container.decodeIfPresent(NetworkResponse.self, forKey: .response)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.error = try container.decodeIfPresent(NetworkError.self, forKey: .error)
        self.metrics = try container.decodeIfPresent(NetworkTaskMetrics.self, forKey: .metrics)
        self.multipartParts = try container.decodeIfPresent([MultipartPart].self, forKey: .multipartParts)
        self.userDetails = try container.decodeIfPresent(JWTUserDetails.self, forKey: .userDetails)
            ?? JWTDecoder.extractFromHeaders(decReq.rawHeaders)
        self.status = try container.decode(TransactionStatus.self, forKey: .status)
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

    public func generateCurl(maskTokens: Bool = false, singleLine: Bool = false) -> String {
        let headersToUse = maskTokens ? request.headers : request.rawHeaders
        let urlString = request.url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        let method = request.rawMethod.uppercased()

        // Base command
        // For GET requests, Postman and POSIX curl prefer omitting explicit "-X GET" and using "curl --location '<url>'"
        // For other methods (POST, PUT, DELETE, PATCH, etc.), use "curl --location --request <METHOD> '<url>'"
        let methodClause: String
        if method == "GET" {
            methodClause = "curl --location '\(urlString)'"
        } else {
            methodClause = "curl --location --request \(method) '\(urlString)'"
        }

        if singleLine {
            var curl = methodClause

            // Append headers
            for (key, value) in headersToUse {
                let headerValue = maskHeaderIfNeeded(key: key, value: value, maskTokens: maskTokens)
                let escaped = headerValue.replacingOccurrences(of: "'", with: "'\\''")
                curl += " --header '\(key): \(escaped)'"
            }

            // Append body
            let bodyData = maskTokens ? request.body : (request.rawBody ?? request.body)
            if let bodyData = bodyData, !bodyData.isEmpty {
                // If JSON, compact it to ensure no newlines in single-line command
                if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData, options: []),
                   let compactData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
                   let compactString = String(data: compactData, encoding: .utf8) {
                    let escaped = compactString.replacingOccurrences(of: "'", with: "'\\''")
                    curl += " --data-raw '\(escaped)'"
                } else if let bodyString = String(data: bodyData, encoding: .utf8) ?? String(data: bodyData, encoding: .ascii) {
                    let flattened = bodyString
                        .replacingOccurrences(of: "\r\n", with: "\\n")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\r", with: "\\r")
                        .replacingOccurrences(of: "'", with: "'\\''")
                    curl += " --data-raw '\(flattened)'"
                }
            }

            return curl
        } else {
            var curl = methodClause

            // Append headers with line continuations
            for (key, value) in headersToUse {
                let headerValue = maskHeaderIfNeeded(key: key, value: value, maskTokens: maskTokens)
                let escaped = headerValue.replacingOccurrences(of: "'", with: "'\\''")
                curl += " \\\n  --header '\(key): \(escaped)'"
            }

            // Append body
            let bodyData = maskTokens ? request.body : (request.rawBody ?? request.body)
            if let bodyData = bodyData, !bodyData.isEmpty,
               let bodyString = String(data: bodyData, encoding: .utf8) ?? String(data: bodyData, encoding: .ascii) {
                let escapedBody = bodyString.replacingOccurrences(of: "'", with: "'\\''")
                curl += " \\\n  --data-raw '\(escapedBody)'"
            }

            return curl
        }
    }

    private func maskHeaderIfNeeded(key: String, value: String, maskTokens: Bool) -> String {
        guard maskTokens else { return value }
        let lower = key.lowercased()
        if lower.contains("authorization") || lower.contains("token") || lower.contains("cookie") || lower.contains("api-key") {
            if value.count > 16 {
                return "\(value.prefix(6))...\(value.suffix(4))"
            } else {
                return "[REDACTED]"
            }
        }
        return value
    }
}


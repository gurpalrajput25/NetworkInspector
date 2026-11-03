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

    private static let headersToOmitFromCurl: Set<String> = [
        "content-length",
        "host",
        "connection"
    ]

    public func generateCurl(maskTokens: Bool = false, singleLine: Bool = false) -> String {
        let headersToUse = maskTokens ? request.headers : request.rawHeaders
        let urlString = request.url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        let method = request.rawMethod.uppercased()

        let isGet = method == "GET"
        let isMultipart = request.isMultipart || (request.contentType?.lowercased().contains("multipart/form-data") == true)

        // Base command
        // For GET requests, Postman and POSIX curl prefer omitting explicit "-X GET" and using "curl --location '<url>'"
        // For other methods (POST, PUT, DELETE, PATCH, etc.), use "curl --location --request <METHOD> '<url>'"
        let methodClause: String
        if isGet {
            methodClause = "curl --location '\(urlString)'"
        } else {
            methodClause = "curl --location --request \(method) '\(urlString)'"
        }

        var curl = methodClause

        // Append headers
        for (key, value) in headersToUse {
            let lower = key.lowercased()
            // Skip pseudo-headers (e.g. :method, :path) and transport-level auto headers
            if key.hasPrefix(":") || Self.headersToOmitFromCurl.contains(lower) {
                continue
            }
            // For multipart with --form, curl automatically creates Content-Type with dynamic boundary
            if isMultipart && lower == "content-type" {
                continue
            }
            let headerValue = maskHeaderIfNeeded(key: key, value: value, maskTokens: maskTokens)
            let escaped = headerValue.replacingOccurrences(of: "'", with: "'\\''")
            if singleLine {
                curl += " --header '\(key): \(escaped)'"
            } else {
                curl += " \\\n  --header '\(key): \(escaped)'"
            }
        }

        // Append body or multipart forms
        if isMultipart, let parts = multipartParts, !parts.isEmpty {
            for part in parts {
                if part.isFile {
                    let fn = (part.filename ?? "file.bin").replacingOccurrences(of: "'", with: "'\\''")
                    if singleLine {
                        curl += " --form '\(part.name)=@\(fn)'"
                    } else {
                        curl += " \\\n  --form '\(part.name)=@\(fn)'"
                    }
                } else {
                    let val = (part.previewContent ?? "").replacingOccurrences(of: "'", with: "'\\''")
                    if singleLine {
                        curl += " --form '\(part.name)=\(val)'"
                    } else {
                        curl += " \\\n  --form '\(part.name)=\(val)'"
                    }
                }
            }
        } else {
            let bodyData = maskTokens ? request.body : (request.rawBody ?? request.body)
            if let bodyData = bodyData, !bodyData.isEmpty {
                // If JSON, compact it to ensure zero newlines in single-line command
                if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData, options: []),
                   let compactData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
                   let compactString = String(data: compactData, encoding: .utf8) {
                    let escaped = compactString.replacingOccurrences(of: "'", with: "'\\''")
                    if singleLine {
                        curl += " --data-raw '\(escaped)'"
                    } else {
                        curl += " \\\n  --data-raw '\(escaped)'"
                    }
                } else if let bodyString = String(data: bodyData, encoding: .utf8) ?? String(data: bodyData, encoding: .ascii) {
                    if singleLine {
                        let flattened = bodyString
                            .replacingOccurrences(of: "\r\n", with: "\\n")
                            .replacingOccurrences(of: "\n", with: "\\n")
                            .replacingOccurrences(of: "\r", with: "\\r")
                            .replacingOccurrences(of: "'", with: "'\\''")
                        curl += " --data-raw '\(flattened)'"
                    } else {
                        let escaped = bodyString.replacingOccurrences(of: "'", with: "'\\''")
                        curl += " \\\n  --data-raw '\(escaped)'"
                    }
                }
            }
        }

        // Add --compressed to multi-line for clean terminal decompression
        if !singleLine {
            curl += " \\\n  --compressed"
        }

        return curl
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


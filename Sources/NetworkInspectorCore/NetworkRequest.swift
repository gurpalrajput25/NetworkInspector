import Foundation

public enum HTTPMethod: String, Codable, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
    case other = "OTHER"

    public init(string: String) {
        let upper = string.uppercased()
        if let match = HTTPMethod.allCases.first(where: { $0.rawValue == upper }) {
            self = match
        } else {
            self = .other
        }
    }
}

public struct NetworkRequest: Identifiable, Codable, Sendable {
    public let id: UUID
    public let url: URL
    public let scheme: String
    public let host: String
    public let path: String
    public let queryItems: [String: String]
    public let method: HTTPMethod
    public let rawMethod: String
    public let headers: [String: String]
    public let rawHeaders: [String: String]
    public let body: Data?
    public let rawBody: Data?
    public let contentType: String?
    public let timestamp: Date
    public let bodySize: Int

    public init(
        id: UUID = UUID(),
        url: URL,
        method: String,
        headers: [String: String] = [:],
        rawHeaders: [String: String]? = nil,
        body: Data? = nil,
        rawBody: Data? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.scheme = url.scheme ?? "https"
        self.host = url.host ?? ""
        self.path = url.path.isEmpty ? "/" : url.path

        var items: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryList = components.queryItems {
            for item in queryList {
                items[item.name] = item.value ?? ""
            }
        }
        self.queryItems = items

        self.rawMethod = method
        self.method = HTTPMethod(string: method)
        self.headers = headers
        self.rawHeaders = rawHeaders ?? headers
        self.body = body
        self.rawBody = rawBody ?? body
        self.bodySize = (rawBody ?? body)?.count ?? 0

        var foundContentType: String?
        for (key, value) in headers {
            if key.caseInsensitiveCompare("Content-Type") == .orderedSame {
                foundContentType = value
                break
            }
        }
        self.contentType = foundContentType
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case id, url, scheme, host, path, queryItems, method, rawMethod, headers, rawHeaders, body, rawBody, contentType, timestamp, bodySize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.url = try container.decode(URL.self, forKey: .url)
        self.scheme = try container.decode(String.self, forKey: .scheme)
        self.host = try container.decode(String.self, forKey: .host)
        self.path = try container.decode(String.self, forKey: .path)
        self.queryItems = try container.decode([String: String].self, forKey: .queryItems)
        self.method = try container.decode(HTTPMethod.self, forKey: .method)
        self.rawMethod = try container.decode(String.self, forKey: .rawMethod)
        let decHeaders = try container.decode([String: String].self, forKey: .headers)
        self.headers = decHeaders
        let decRawHeaders = try container.decodeIfPresent([String: String].self, forKey: .rawHeaders)
        self.rawHeaders = decRawHeaders ?? decHeaders
        let decBody = try container.decodeIfPresent(Data.self, forKey: .body)
        self.body = decBody
        let decRawBody = try container.decodeIfPresent(Data.self, forKey: .rawBody)
        self.rawBody = decRawBody ?? decBody
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.bodySize = try container.decode(Int.self, forKey: .bodySize)
    }

    public var bodyString: String? {
        guard let body = body, !body.isEmpty else { return nil }
        return String(data: body, encoding: .utf8)
            ?? String(data: body, encoding: .ascii)
    }

    public var isJSON: Bool {
        contentType?.lowercased().contains("application/json") == true
    }

    public var isMultipart: Bool {
        contentType?.lowercased().contains("multipart/form-data") == true
    }
}


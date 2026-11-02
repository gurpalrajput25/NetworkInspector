import Foundation

public struct JWTUserDetails: Codable, Sendable, Identifiable {
    public var id: String { userId ?? email ?? UUID().uuidString }
    public let userId: String?
    public let email: String?
    public let name: String?
    public let role: String?
    public let organizerId: String?
    public let expirationDate: Date?
    public let issuedAt: Date?
    public let rawPayload: [String: String]

    public init(
        userId: String? = nil,
        email: String? = nil,
        name: String? = nil,
        role: String? = nil,
        organizerId: String? = nil,
        expirationDate: Date? = nil,
        issuedAt: Date? = nil,
        rawPayload: [String: String] = [:]
    ) {
        self.userId = userId
        self.email = email
        self.name = name
        self.role = role
        self.organizerId = organizerId
        self.expirationDate = expirationDate
        self.issuedAt = issuedAt
        self.rawPayload = rawPayload
    }

    public var isExpired: Bool {
        guard let exp = expirationDate else { return false }
        return exp < Date()
    }
}

public enum JWTDecoder {

    public static func decode(jwt: String) -> JWTUserDetails? {
        let cleanToken = jwt
            .replacingOccurrences(of: "Bearer ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let segments = cleanToken.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = String(segments[1])
        guard let payloadData = base64URLDecode(payloadSegment),
              let json = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] else {
            return nil
        }

        let userId = (json["sub"] ?? json["id"] ?? json["userId"] ?? json["user_id"]) as? String
        let email = json["email"] as? String
        let role = (json["role"] ?? json["user_role"] ?? json["userRole"]) as? String
        let organizerId = (json["organizer_id"] ?? json["organizerId"] ?? json["org_id"]) as? String

        var fullName = json["name"] as? String
        if fullName == nil, let first = json["first_name"] as? String {
            let last = (json["last_name"] as? String) ?? ""
            fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        }

        var expirationDate: Date?
        if let exp = json["exp"] as? Double {
            expirationDate = Date(timeIntervalSince1970: exp)
        } else if let expInt = json["exp"] as? Int {
            expirationDate = Date(timeIntervalSince1970: TimeInterval(expInt))
        }

        var issuedAt: Date?
        if let iat = json["iat"] as? Double {
            issuedAt = Date(timeIntervalSince1970: iat)
        } else if let iatInt = json["iat"] as? Int {
            issuedAt = Date(timeIntervalSince1970: TimeInterval(iatInt))
        }

        var stringPayload: [String: String] = [:]
        for (k, v) in json {
            stringPayload[k] = "\(v)"
        }

        return JWTUserDetails(
            userId: userId,
            email: email,
            name: fullName,
            role: role,
            organizerId: organizerId,
            expirationDate: expirationDate,
            issuedAt: issuedAt,
            rawPayload: stringPayload
        )
    }

    public static func extractFromHeaders(_ headers: [String: String]) -> JWTUserDetails? {
        for (key, value) in headers {
            let lower = key.lowercased()
            if lower == "authorization" || lower == "token" || lower == "x-access-token" {
                if let details = decode(jwt: value) {
                    return details
                }
            }
        }
        return nil
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }
}


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
        var cleanToken = jwt.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove auth prefixes case-insensitively
        let prefixes = ["bearer ", "jwt ", "token "]
        for prefix in prefixes {
            if cleanToken.lowercased().hasPrefix(prefix) {
                cleanToken = String(cleanToken.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        let segments = cleanToken.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = String(segments[1])
        guard let payloadData = base64URLDecode(payloadSegment),
              let json = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] else {
            return nil
        }

        let userId = stringValue(from: json, keys: [
            "sub", "id", "userId", "user_id", "uid", "accountId", "account_id", "oid", "sub_id"
        ])
        let email = stringValue(from: json, keys: [
            "email", "email_address", "mail", "preferred_username", "upn", "user_email"
        ])
        let role = stringValue(from: json, keys: [
            "role", "user_role", "userRole", "roles", "scope", "scp", "authorities", "groups"
        ])
        let organizerId = stringValue(from: json, keys: [
            "organizer_id", "organizerId", "org_id", "orgId", "tenant_id", "tenantId", "tid", "company_id", "companyId"
        ])

        var fullName = stringValue(from: json, keys: [
            "name", "fullName", "full_name", "displayName", "display_name", "username", "cognito:username"
        ])
        if fullName == nil {
            let first = stringValue(from: json, keys: ["first_name", "given_name", "firstName"]) ?? ""
            let last = stringValue(from: json, keys: ["last_name", "family_name", "lastName"]) ?? ""
            let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            if !combined.isEmpty {
                fullName = combined
            }
        }

        var expirationDate: Date?
        if let exp = json["exp"] as? Double {
            expirationDate = Date(timeIntervalSince1970: exp)
        } else if let expInt = json["exp"] as? Int {
            expirationDate = Date(timeIntervalSince1970: TimeInterval(expInt))
        } else if let expStr = json["exp"] as? String, let expDbl = Double(expStr) {
            expirationDate = Date(timeIntervalSince1970: expDbl)
        }

        var issuedAt: Date?
        if let iat = json["iat"] as? Double {
            issuedAt = Date(timeIntervalSince1970: iat)
        } else if let iatInt = json["iat"] as? Int {
            issuedAt = Date(timeIntervalSince1970: TimeInterval(iatInt))
        } else if let iatStr = json["iat"] as? String, let iatDbl = Double(iatStr) {
            issuedAt = Date(timeIntervalSince1970: iatDbl)
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

    private static func stringValue(from json: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let val = json[key] {
                if let str = val as? String, !str.isEmpty {
                    return str
                }
                if let num = val as? NSNumber {
                    return num.stringValue
                }
                if let arr = val as? [Any], !arr.isEmpty {
                    let items = arr.map { "\($0)" }.joined(separator: ", ")
                    if !items.isEmpty { return items }
                }
            }
        }
        return nil
    }

    public static func extractFromHeaders(_ headers: [String: String]) -> JWTUserDetails? {
        let authKeys = [
            "authorization",
            "token",
            "x-access-token",
            "x-auth-token",
            "auth-token",
            "bearer-token",
            "authentication",
            "id-token"
        ]

        for (key, value) in headers {
            let lower = key.lowercased()
            if authKeys.contains(lower) {
                if let details = decode(jwt: value) {
                    return details
                }
            }
        }
        return nil
    }

    /// Extracts JWT user details from login or authentication response bodies
    public static func extractFromResponseBody(_ data: Data) -> JWTUserDetails? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }

        let tokenKeys = ["token", "access_token", "accessToken", "id_token", "idToken", "jwt"]
        for key in tokenKeys {
            if let tokenStr = json[key] as? String, let user = decode(jwt: tokenStr) {
                return user
            }
        }

        // Check nested data / result dictionary
        if let nested = (json["data"] ?? json["result"] ?? json["payload"]) as? [String: Any] {
            for key in tokenKeys {
                if let tokenStr = nested[key] as? String, let user = decode(jwt: tokenStr) {
                    return user
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


import Foundation
import NetworkInspectorCore

public struct SensitiveDataRedactor: Sendable {
    private let config: NetworkPrivacyConfiguration

    public init(configuration: NetworkPrivacyConfiguration = .default) {
        self.config = configuration
    }

    public func redactHeaders(_ headers: [String: String]) -> [String: String] {
        var redacted: [String: String] = [:]
        for (key, value) in headers {
            let lowerKey = key.lowercased()
            if config.sensitiveHeaderKeys.contains(lowerKey) {
                redacted[key] = maskSensitiveValue(value)
            } else {
                redacted[key] = value
            }
        }
        return redacted
    }

    public func maskSensitiveValue(_ value: String) -> String {
        guard value.count > 12 else {
            return "[REDACTED]"
        }
        return "\(value.prefix(4))••••••••\(value.suffix(4))"
    }

    public func redactBody(_ data: Data?, contentType: String?) -> Data? {
        guard let data = data, !data.isEmpty else { return nil }

        // If not JSON, check if it's text or binary
        guard let contentType = contentType?.lowercased(), contentType.contains("application/json") else {
            return data
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let sanitizedObject = redactJSONObject(jsonObject) else {
            return data
        }

        return try? JSONSerialization.data(withJSONObject: sanitizedObject, options: [.prettyPrinted])
    }

    private func redactJSONObject(_ object: Any) -> Any? {
        if let dict = object as? [String: Any] {
            var newDict: [String: Any] = [:]
            for (k, v) in dict {
                let lowerK = k.lowercased()
                if config.sensitiveBodyFields.contains(lowerK) {
                    newDict[k] = "[REDACTED]"
                } else if let nested = redactJSONObject(v) {
                    newDict[k] = nested
                } else {
                    newDict[k] = v
                }
            }
            return newDict
        } else if let array = object as? [Any] {
            return array.compactMap { redactJSONObject($0) }
        }
        return object
    }

    public func sanitizeTransaction(_ transaction: NetworkTransaction) -> NetworkTransaction {
        var sanitized = transaction

        let redactedReqHeaders = redactHeaders(transaction.request.headers)
        let redactedReqBody = redactBody(transaction.request.body, contentType: transaction.request.contentType)

        sanitized.request = NetworkRequest(
            id: transaction.request.id,
            url: transaction.request.url,
            method: transaction.request.rawMethod,
            headers: redactedReqHeaders,
            body: redactedReqBody,
            timestamp: transaction.request.timestamp
        )

        if let response = transaction.response {
            let redactedResHeaders = redactHeaders(response.headers)
            let redactedResBody = redactBody(response.body, contentType: response.mimeType)

            sanitized.response = NetworkResponse(
                statusCode: response.statusCode,
                headers: redactedResHeaders,
                body: redactedResBody,
                mimeType: response.mimeType,
                contentLength: response.contentLength,
                timestamp: response.timestamp
            )
        }

        return sanitized
    }
}


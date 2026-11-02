import Foundation

public struct NetworkPrivacyConfiguration: Sendable {
    public var sensitiveHeaderKeys: Set<String>
    public var sensitiveBodyFields: Set<String>
    public var excludedHosts: Set<String>
    public var includedHosts: Set<String>?
    public var isBodyCaptureEnabled: Bool
    public var maxBodySize: Int
    public var maskTokensInExports: Bool

    public static let `default` = NetworkPrivacyConfiguration(
        sensitiveHeaderKeys: [
            "authorization",
            "proxy-authorization",
            "cookie",
            "set-cookie",
            "x-api-key",
            "apikey",
            "api-key"
        ],
        sensitiveBodyFields: [
            "password",
            "pass",
            "secret",
            "token",
            "access_token",
            "refresh_token",
            "id_token",
            "apiKey",
            "api_key",
            "creditcard",
            "card_number",
            "cvv",
            "cvc",
            "ssn"
        ],
        excludedHosts: [],
        includedHosts: nil,
        isBodyCaptureEnabled: true,
        maxBodySize: 1_000_000,
        maskTokensInExports: true
    )

    public init(
        sensitiveHeaderKeys: Set<String> = NetworkPrivacyConfiguration.default.sensitiveHeaderKeys,
        sensitiveBodyFields: Set<String> = NetworkPrivacyConfiguration.default.sensitiveBodyFields,
        excludedHosts: Set<String> = [],
        includedHosts: Set<String>? = nil,
        isBodyCaptureEnabled: Bool = true,
        maxBodySize: Int = 1_000_000,
        maskTokensInExports: Bool = true
    ) {
        self.sensitiveHeaderKeys = Set(sensitiveHeaderKeys.map { $0.lowercased() })
        self.sensitiveBodyFields = Set(sensitiveBodyFields.map { $0.lowercased() })
        self.excludedHosts = Set(excludedHosts.map { $0.lowercased() })
        self.includedHosts = includedHosts.map { Set($0.map { $0.lowercased() }) }
        self.isBodyCaptureEnabled = isBodyCaptureEnabled
        self.maxBodySize = maxBodySize
        self.maskTokensInExports = maskTokensInExports
    }

    public func shouldCapture(host: String) -> Bool {
        let lower = host.lowercased()
        if excludedHosts.contains(lower) {
            return false
        }
        if let included = includedHosts {
            return included.contains(lower)
        }
        return true
    }
}


import Foundation
import NetworkInspectorPrivacy

public struct NetworkInspectorConfiguration: Sendable {
    public var isEnabled: Bool
    public var captureRequestHeaders: Bool
    public var captureResponseHeaders: Bool
    public var captureRequestBody: Bool
    public var captureResponseBody: Bool
    public var maxLogCount: Int
    public var maxBodySize: Int
    public var enableAnalytics: Bool
    public var enablePersistence: Bool
    public var environmentName: String
    public var privacy: NetworkPrivacyConfiguration
    public var teamsWebhookURL: URL?
    public var postmanAPIKey: String?
    public var postmanCollectionUID: String?
    public var postmanWorkspaceID: String?
    public var isShakeToOpenEnabled: Bool

    public static let development = NetworkInspectorConfiguration(
        isEnabled: true,
        captureRequestHeaders: true,
        captureResponseHeaders: true,
        captureRequestBody: true,
        captureResponseBody: true,
        maxLogCount: 1000,
        maxBodySize: 1_000_000,
        enableAnalytics: true,
        enablePersistence: true,
        environmentName: "Development",
        privacy: .default,
        teamsWebhookURL: nil,
        isShakeToOpenEnabled: true
    )

    public static let staging = NetworkInspectorConfiguration(
        isEnabled: true,
        captureRequestHeaders: true,
        captureResponseHeaders: true,
        captureRequestBody: true,
        captureResponseBody: true,
        maxLogCount: 500,
        maxBodySize: 500_000,
        enableAnalytics: true,
        enablePersistence: false,
        environmentName: "Staging",
        privacy: .default,
        teamsWebhookURL: nil,
        isShakeToOpenEnabled: true
    )

    public static let production = NetworkInspectorConfiguration(
        isEnabled: false, // Safe default in production
        captureRequestHeaders: false,
        captureResponseHeaders: false,
        captureRequestBody: false,
        captureResponseBody: false,
        maxLogCount: 100,
        maxBodySize: 0,
        enableAnalytics: false,
        enablePersistence: false,
        environmentName: "Production",
        privacy: .default,
        teamsWebhookURL: nil,
        isShakeToOpenEnabled: false
    )

    public init(
        isEnabled: Bool = true,
        captureRequestHeaders: Bool = true,
        captureResponseHeaders: Bool = true,
        captureRequestBody: Bool = true,
        captureResponseBody: Bool = true,
        maxLogCount: Int = 1000,
        maxBodySize: Int = 1_000_000,
        enableAnalytics: Bool = true,
        enablePersistence: Bool = true,
        environmentName: String = "Development",
        privacy: NetworkPrivacyConfiguration = .default,
        teamsWebhookURL: URL? = nil,
        postmanAPIKey: String? = nil,
        postmanCollectionUID: String? = nil,
        postmanWorkspaceID: String? = nil,
        isShakeToOpenEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.captureRequestHeaders = captureRequestHeaders
        self.captureResponseHeaders = captureResponseHeaders
        self.captureRequestBody = captureRequestBody
        self.captureResponseBody = captureResponseBody
        self.maxLogCount = maxLogCount
        self.maxBodySize = maxBodySize
        self.enableAnalytics = enableAnalytics
        self.enablePersistence = enablePersistence
        self.environmentName = environmentName
        self.privacy = privacy
        self.teamsWebhookURL = teamsWebhookURL
        self.postmanAPIKey = postmanAPIKey
        self.postmanCollectionUID = postmanCollectionUID
        self.postmanWorkspaceID = postmanWorkspaceID
        self.isShakeToOpenEnabled = isShakeToOpenEnabled
    }
}


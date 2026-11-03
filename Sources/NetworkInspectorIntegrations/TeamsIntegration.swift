import Foundation
import NetworkInspectorCore
import NetworkInspectorAnalytics

public final class TeamsIntegration: @unchecked Sendable {
    public static let shared = TeamsIntegration()

    public var webhookURL: URL?
    public var environmentName: String = "Development"
    public var postmanService: PostmanCloudService?

    private let session: URLSession

    public init(
        webhookURL: URL? = nil,
        environmentName: String = "Development",
        postmanService: PostmanCloudService? = nil
    ) {
        self.webhookURL = webhookURL
        self.environmentName = environmentName
        self.postmanService = postmanService

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    public func configure(webhookURL: URL?, environmentName: String = "Development") {
        self.webhookURL = webhookURL
        self.environmentName = environmentName
    }

    /// Retained for backward compatibility.
    @available(*, deprecated, message: "Postman synchronization is deprecated in favor of native API standards & AI suggestions.")
    public func configurePostman(apiKey: String, collectionUid: String, workspaceId: String) {
        self.postmanService = PostmanCloudService(
            apiKey: apiKey,
            collectionUid: collectionUid,
            workspaceId: workspaceId
        )
    }

    /// Dispatches a trace to Teams with optional AI Suggestions and Request Analytics.
    public func send(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        customWebhookURL: URL? = nil,
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        includeAISuggestions: Bool = true,
        includeAnalytics: Bool = true,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let targetURL = customWebhookURL ?? self.webhookURL else {
            completion(.failure(NSError(
                domain: "TeamsIntegration",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "No Teams or Power Automate Webhook URL configured."]
            )))
            return
        }

        let aiReport = includeAISuggestions ? APISuggestionEngine.analyze(transaction: transaction) : nil
        let analytics = includeAnalytics ? RequestAnalyticsBuilder.build(for: transaction) : nil

        let card = TeamsNotificationBuilder.buildAdaptiveCard(
            transaction: transaction,
            developerNote: developerNote,
            environmentName: self.environmentName,
            customUser: customUser,
            maskTokens: maskTokens,
            aiSuggestionReport: aiReport,
            requestAnalytics: analytics
        )

        let payload: [String: Any] = [
            "type": "message",
            "attachments": [
                [
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": card
                ]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(NSError(
                domain: "TeamsIntegration",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Failed to serialize Adaptive Card payload."]
            )))
            return
        }

        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        session.dataTask(with: request) { _, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(statusCode) {
                DispatchQueue.main.async { completion(.success(())) }
            } else {
                let err = NSError(
                    domain: "TeamsIntegration",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Teams endpoint returned HTTP status \(statusCode)."]
                )
                DispatchQueue.main.async { completion(.failure(err)) }
            }
        }.resume()
    }

    /// Backward-compatible overload with syncToPostman parameter (ignored).
    public func send(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        customWebhookURL: URL? = nil,
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        syncToPostman: Bool = false,
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        send(
            transaction: transaction,
            developerNote: developerNote,
            customWebhookURL: customWebhookURL,
            customUser: customUser,
            maskTokens: maskTokens,
            includeAISuggestions: true,
            includeAnalytics: true
        ) { result in
            switch result {
            case .success:
                completion(.success(nil))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Backward-compatible overload returning `Result<Void, Error>`
    public func send(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        customWebhookURL: URL? = nil,
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        send(
            transaction: transaction,
            developerNote: developerNote,
            customWebhookURL: customWebhookURL,
            customUser: customUser,
            maskTokens: maskTokens,
            includeAISuggestions: true,
            includeAnalytics: true,
            completion: completion
        )
    }
}

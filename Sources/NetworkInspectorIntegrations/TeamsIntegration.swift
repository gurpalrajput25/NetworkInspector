import Foundation
import NetworkInspectorCore

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

    /// Configures Postman Cloud API synchronization for 1-click execution.
    public func configurePostman(apiKey: String, collectionUid: String, workspaceId: String) {
        self.postmanService = PostmanCloudService(
            apiKey: apiKey,
            collectionUid: collectionUid,
            workspaceId: workspaceId
        )
    }

    /// Dispatches a trace to Teams, optionally synchronizing with Postman Cloud to generate an "🚀 Open in Postman" deep link button.
    public func send(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        customWebhookURL: URL? = nil,
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        syncToPostman: Bool = true,
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        guard let targetURL = customWebhookURL ?? self.webhookURL else {
            completion(.failure(NSError(
                domain: "TeamsIntegration",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "No Teams or Power Automate Webhook URL configured."]
            )))
            return
        }

        // If Postman Cloud Service is configured and syncToPostman is enabled, push first to Postman Cloud
        if syncToPostman, let postman = self.postmanService {
            postman.exportTransaction(transaction: transaction, maskTokens: maskTokens) { [weak self] postmanResult in
                guard let self = self else { return }
                let deepLink = try? postmanResult.get()
                self.dispatchToTeams(
                    transaction: transaction,
                    targetURL: targetURL,
                    postmanDeepLink: deepLink,
                    developerNote: developerNote,
                    customUser: customUser,
                    maskTokens: maskTokens
                ) { teamsResult in
                    switch teamsResult {
                    case .success:
                        completion(.success(deepLink))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        } else {
            dispatchToTeams(
                transaction: transaction,
                targetURL: targetURL,
                postmanDeepLink: nil,
                developerNote: developerNote,
                customUser: customUser,
                maskTokens: maskTokens
            ) { teamsResult in
                switch teamsResult {
                case .success:
                    completion(.success(nil))
                case .failure(let error):
                    completion(.failure(error))
                }
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
            syncToPostman: postmanService != nil
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func dispatchToTeams(
        transaction: NetworkTransaction,
        targetURL: URL,
        postmanDeepLink: String?,
        developerNote: String?,
        customUser: JWTUserDetails?,
        maskTokens: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let payload = TeamsAdaptiveCardBuilder.buildPayload(
            transaction: transaction,
            postmanDeepLink: postmanDeepLink,
            developerNote: developerNote,
            userDetails: customUser,
            maskTokens: maskTokens
        )

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
}

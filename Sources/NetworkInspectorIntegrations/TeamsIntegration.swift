import Foundation
import NetworkInspectorCore

public final class TeamsIntegration: @unchecked Sendable {
    public static let shared = TeamsIntegration()

    public var webhookURL: URL?
    public var environmentName: String = "Development"

    private let session: URLSession

    public init(webhookURL: URL? = nil, environmentName: String = "Development") {
        self.webhookURL = webhookURL
        self.environmentName = environmentName

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    public func configure(webhookURL: URL?, environmentName: String = "Development") {
        self.webhookURL = webhookURL
        self.environmentName = environmentName
    }

    public func send(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        customWebhookURL: URL? = nil,
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false,
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

        let payload = TeamsNotificationBuilder.buildAdaptiveCard(
            transaction: transaction,
            developerNote: developerNote,
            environmentName: environmentName,
            customUser: customUser,
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

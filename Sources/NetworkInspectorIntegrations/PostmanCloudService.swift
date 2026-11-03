import Foundation
import NetworkInspectorCore

public final class PostmanCloudService: @unchecked Sendable {
    public let apiKey: String
    public let collectionUid: String
    public let workspaceId: String
    private let session: URLSession

    public init(apiKey: String, collectionUid: String, workspaceId: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.collectionUid = collectionUid
        self.workspaceId = workspaceId
        self.session = session
    }

    /// Pushes an intercepted Foundation `URLRequest` to the target Postman Cloud collection and returns the desktop/web deep link.
    public func exportRequest(
        request: URLRequest,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let targetUrl = request.url?.absoluteString else {
            completion(.failure(NSError(domain: "NetworkInspector", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Request URL"])))
            return
        }

        let endpoint = URL(string: "https://api.getpostman.com/collections/\(collectionUid)/requests")!
        var apiReq = URLRequest(url: endpoint)
        apiReq.httpMethod = "POST"
        apiReq.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        apiReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build Postman request entity
        var postmanHeaders: [[String: String]] = []
        request.allHTTPHeaderFields?.forEach { k, v in
            postmanHeaders.append(["key": k, "value": v])
        }

        var postmanBody: [String: Any]? = nil
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8), !bodyString.isEmpty {
            postmanBody = [
                "mode": "raw",
                "raw": bodyString,
                "options": ["raw": ["language": "json"]]
            ]
        }

        let endpointPath = request.url?.path.isEmpty == false ? request.url!.path : "/"
        let payload: [String: Any] = [
            "name": "[\(request.httpMethod ?? "GET")] \(endpointPath)",
            "request": [
                "url": targetUrl,
                "method": request.httpMethod ?? "GET",
                "header": postmanHeaders,
                "body": postmanBody as Any
            ]
        ]

        do {
            apiReq.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        session.dataTask(with: apiReq) { [workspaceId] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "NetworkInspector", code: 502, userInfo: [NSLocalizedDescriptionKey: "Malformed Postman API Response"])))
                return
            }

            let requestId = (json["data"] as? [String: Any])?["id"] as? String
                ?? json["id"] as? String
                ?? (json["collection"] as? [String: Any])?["id"] as? String

            guard let finalRequestId = requestId, !finalRequestId.isEmpty else {
                completion(.failure(NSError(domain: "NetworkInspector", code: 502, userInfo: [NSLocalizedDescriptionKey: "Postman API response missing request ID."])))
                return
            }

            // Universal deep-link format that triggers Postman desktop
            let deepLink = "https://go.postman.co/workspace/\(workspaceId)/request/\(finalRequestId)"
            completion(.success(deepLink))
        }.resume()
    }

    /// Pushes an intercepted `NetworkTransaction` to the target Postman Cloud collection and returns the deep link.
    public func exportTransaction(
        transaction: NetworkTransaction,
        maskTokens: Bool = false,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let headersToUse = maskTokens ? transaction.request.headers : transaction.request.rawHeaders
        let bodyData = maskTokens ? transaction.request.body : (transaction.request.rawBody ?? transaction.request.body)

        var urlReq = URLRequest(url: transaction.request.url)
        urlReq.httpMethod = transaction.request.rawMethod
        for (k, v) in headersToUse {
            urlReq.setValue(v, forHTTPHeaderField: k)
        }
        urlReq.httpBody = bodyData

        exportRequest(request: urlReq, completion: completion)
    }
}

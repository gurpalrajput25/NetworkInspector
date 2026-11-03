import Foundation
import NetworkInspectorCore

public enum PostmanLinkBuilder {

    /// Default hosted GitHub Pages web bridge that auto-copies cURL and launches Postman Desktop (`postman://`).
    public static var defaultWebHelperBaseURL: String = "https://gurpalrajput25.github.io/NetworkInspector/import.html"

    /// Builds a universal client-side import URL with the request payload encoded into the URL hash fragment (`#data=...`).
    /// The hash is processed entirely in the user's browser, ensuring zero server transmission of tokens.
    public static func buildImportLink(
        curlString: String,
        transaction: NetworkTransaction? = nil,
        baseURL: String = defaultWebHelperBaseURL
    ) -> String {
        var payload: [String: Any] = [
            "curl": curlString
        ]

        if let tx = transaction {
            payload["method"] = tx.request.rawMethod
            payload["url"] = tx.request.url.absoluteString
            payload["headers"] = tx.request.rawHeaders.isEmpty ? tx.request.headers : tx.request.rawHeaders

            let bodyData = tx.request.rawBody ?? tx.request.body
            if let bodyData = bodyData,
               let bodyStr = String(data: bodyData, encoding: .utf8),
               bodyStr.count <= 3000 {
                payload["body"] = bodyStr
            }
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            let base64 = jsonData.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return "\(baseURL)#data=\(base64)"
        }

        let encoded = curlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "\(baseURL)#curl=\(encoded)"
    }

    /// Builds an import URL directly from a standard Foundation `URLRequest`.
    public static func buildImportLink(
        request: URLRequest,
        baseURL: String = defaultWebHelperBaseURL
    ) -> String {
        let curl = CurlFormatter.format(request: request)
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }

        var payload: [String: Any] = [
            "curl": curl,
            "method": request.httpMethod ?? "GET",
            "url": request.url?.absoluteString ?? "",
            "headers": headers
        ]

        if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8), bodyStr.count <= 3000 {
            payload["body"] = bodyStr
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            let base64 = jsonData.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return "\(baseURL)#data=\(base64)"
        }

        let encoded = curl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "\(baseURL)#curl=\(encoded)"
    }
}

import Foundation

public struct CurlFormatter {

    private static let omittedHeaders: Set<String> = [
        "connection",
        "content-length",
        "accept-encoding"
    ]

    /// Formats a standard Foundation `URLRequest` into a cURL command string with escaped single quotes and line continuation backslashes.
    public static func format(request: URLRequest, singleLine: Bool = false) -> String {
        guard let rawUrl = request.url?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines), !rawUrl.isEmpty else {
            return ""
        }
        let method = request.httpMethod?.uppercased() ?? "GET"
        let safeUrl = rawUrl.replacingOccurrences(of: "'", with: "%27")

        var lines: [String] = ["curl -X \(method) '\(safeUrl)'"]

        // Append Headers with line continuation
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }) {
                let lower = key.lowercased()
                if key.hasPrefix(":") || omittedHeaders.contains(lower) {
                    continue
                }
                let cleanValue = value
                    .replacingOccurrences(of: "\r", with: "")
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "'", with: "'\\''")
                lines.append("  -H '\(key): \(cleanValue)'")
            }
        }

        // Append HTTP Body
        if let bodyData = request.httpBody, !bodyData.isEmpty {
            if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData, options: []),
               let compactData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
               let compactString = String(data: compactData, encoding: .utf8) {
                let sanitizedBody = compactString.replacingOccurrences(of: "'", with: "'\\''")
                lines.append("  --data '\(sanitizedBody)'")
            } else if let bodyString = String(data: bodyData, encoding: .utf8) ?? String(data: bodyData, encoding: .ascii),
                      !bodyString.isEmpty {
                let sanitizedBody = bodyString
                    .replacingOccurrences(of: "\r\n", with: "\\n")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "'", with: "'\\''")
                lines.append("  --data '\(sanitizedBody)'")
            }
        }

        return singleLine ? lines.joined(separator: " ") : lines.joined(separator: " \\\n")
    }

    /// Formats a `NetworkRequest` into a cURL command string.
    public static func format(request: NetworkRequest, maskTokens: Bool = false, singleLine: Bool = false) -> String {
        let headersToUse = maskTokens
            ? request.headers
            : (request.rawHeaders.isEmpty ? request.headers : request.rawHeaders)
        let rawUrl = request.url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeUrl = rawUrl.replacingOccurrences(of: "'", with: "%27")
        let method = request.rawMethod.uppercased()

        var lines: [String] = ["curl -X \(method) '\(safeUrl)'"]

        for (key, value) in headersToUse.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }) {
            let lower = key.lowercased()
            if key.hasPrefix(":") || omittedHeaders.contains(lower) {
                continue
            }
            let cleanValue = value
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "'", with: "'\\''")
            lines.append("  -H '\(key): \(cleanValue)'")
        }

        let bodyData = maskTokens ? request.body : (request.rawBody ?? request.body)
        if let bodyData = bodyData, !bodyData.isEmpty {
            if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData, options: []),
               let compactData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
               let compactString = String(data: compactData, encoding: .utf8) {
                let sanitizedBody = compactString.replacingOccurrences(of: "'", with: "'\\''")
                lines.append("  --data '\(sanitizedBody)'")
            } else if let bodyString = String(data: bodyData, encoding: .utf8) ?? String(data: bodyData, encoding: .ascii),
                      !bodyString.isEmpty {
                let sanitizedBody = bodyString
                    .replacingOccurrences(of: "\r\n", with: "\\n")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "'", with: "'\\''")
                lines.append("  --data '\(sanitizedBody)'")
            }
        }

        return singleLine ? lines.joined(separator: " ") : lines.joined(separator: " \\\n")
    }

    /// Formats a `NetworkTransaction` into a cURL command string.
    public static func format(transaction: NetworkTransaction, maskTokens: Bool = false, singleLine: Bool = false) -> String {
        format(request: transaction.request, maskTokens: maskTokens, singleLine: singleLine)
    }
}

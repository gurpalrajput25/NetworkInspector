import Foundation
import NetworkInspectorCore

public enum ExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case har = "HAR"
    case csv = "CSV"
    case curl = "cURL"
    case diagnostic = "Diagnostic Report"

    public var id: String { rawValue }
    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .har: return "har"
        case .csv: return "csv"
        case .curl: return "sh"
        case .diagnostic: return "txt"
        }
    }
}

public enum NetworkLogExporter {

    public static func export(transactions: [NetworkTransaction], format: ExportFormat) -> Data? {
        switch format {
        case .json:
            return exportJSON(transactions)
        case .har:
            return exportHAR(transactions)
        case .csv:
            return exportCSV(transactions)
        case .curl:
            return exportCurl(transactions)
        case .diagnostic:
            return exportDiagnostic(transactions)
        }
    }

    public static func exportJSON(_ transactions: [NetworkTransaction]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(transactions)
    }

    public static func exportHAR(_ transactions: [NetworkTransaction]) -> Data? {
        var entries: [[String: Any]] = []

        let isoFormatter = ISO8601DateFormatter()

        for t in transactions {
            let startedDateTime = isoFormatter.string(from: t.request.timestamp)
            let timeMs = (t.duration ?? 0) * 1000

            var requestHeaders: [[String: String]] = []
            for (k, v) in t.request.headers {
                requestHeaders.append(["name": k, "value": v])
            }

            var responseHeaders: [[String: String]] = []
            if let res = t.response {
                for (k, v) in res.headers {
                    responseHeaders.append(["name": k, "value": v])
                }
            }

            var postData: [String: Any]?
            if let bodyStr = t.request.bodyString {
                postData = [
                    "mimeType": t.request.contentType ?? "text/plain",
                    "text": bodyStr
                ]
            }

            var responseContent: [String: Any] = [
                "size": t.response?.contentLength ?? 0,
                "mimeType": t.response?.mimeType ?? "text/plain"
            ]
            if let resBody = t.response?.bodyString {
                responseContent["text"] = resBody
            }

            let entry: [String: Any] = [
                "startedDateTime": startedDateTime,
                "time": timeMs,
                "request": [
                    "method": t.request.rawMethod,
                    "url": t.request.url.absoluteString,
                    "httpVersion": "HTTP/1.1",
                    "headers": requestHeaders,
                    "queryString": t.request.queryItems.map { ["name": $0.key, "value": $0.value] },
                    "postData": postData as Any,
                    "headersSize": -1,
                    "bodySize": t.request.bodySize
                ],
                "response": [
                    "status": t.response?.statusCode ?? 0,
                    "statusText": t.response?.statusDescription ?? "Error",
                    "httpVersion": "HTTP/1.1",
                    "headers": responseHeaders,
                    "content": responseContent,
                    "redirectURL": "",
                    "headersSize": -1,
                    "bodySize": t.response?.contentLength ?? 0
                ],
                "cache": [:],
                "timings": [
                    "send": (t.metrics?.requestDuration ?? 0) * 1000,
                    "wait": (t.metrics?.waitDuration ?? 0) * 1000,
                    "receive": (t.metrics?.responseDuration ?? 0) * 1000
                ]
            ]
            entries.append(entry)
        }

        let har: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": [
                    "name": "NetworkInspector iOS",
                    "version": "1.0.0"
                ],
                "entries": entries
            ]
        ]

        return try? JSONSerialization.data(withJSONObject: har, options: [.prettyPrinted])
    }

    public static func exportCSV(_ transactions: [NetworkTransaction]) -> Data? {
        var csv = "ID,Timestamp,Method,URL,Status,Duration (ms),Request Size (bytes),Response Size (bytes),Client Source,Error\n"

        let formatter = ISO8601DateFormatter()

        for t in transactions {
            let id = t.id.uuidString
            let time = formatter.string(from: t.request.timestamp)
            let method = t.request.rawMethod
            let url = "\"\(t.request.url.absoluteString.replacingOccurrences(of: "\"", with: "\"\""))\""
            let status = "\(t.response?.statusCode ?? 0)"
            let duration = String(format: "%.1f", (t.duration ?? 0) * 1000)
            let reqSize = "\(t.request.bodySize)"
            let resSize = "\(t.response?.contentLength ?? 0)"
            let client = t.clientSource
            let err = "\"\(t.error?.localizedDescription.replacingOccurrences(of: "\"", with: "\"\"") ?? "")\""

            csv += "\(id),\(time),\(method),\(url),\(status),\(duration),\(reqSize),\(resSize),\(client),\(err)\n"
        }

        return csv.data(using: .utf8)
    }

    public static func exportCurl(_ transactions: [NetworkTransaction]) -> Data? {
        var script = "#!/usr/bin/env bash\n# Generated by NetworkInspector\n\n"
        for t in transactions {
            script += "# [\(t.request.rawMethod)] \(t.request.url.absoluteString)\n"
            script += t.generateCurl(maskTokens: true) + "\n\n"
        }
        return script.data(using: .utf8)
    }

    public static func exportDiagnostic(_ transactions: [NetworkTransaction]) -> Data? {
        let total = transactions.count
        let errors = transactions.filter { ($0.response?.statusCode ?? 0) >= 400 || $0.error != nil }
        let avgDur = total > 0 ? transactions.compactMap { $0.duration }.reduce(0, +) / Double(total) : 0

        var report = """
        ================================================================================
        🚀 NetworkInspector Diagnostic Report
        Generated: \(Date().formatted(date: .abbreviated, time: .standard))
        ================================================================================

        SUMMARY:
        - Total Requests  : \(total)
        - Total Errors    : \(errors.count) (Failure rate: \(total > 0 ? String(format: "%.1f%%", Double(errors.count) / Double(total) * 100) : "0%"))
        - Average Latency : \(String(format: "%.2f s", avgDur))

        --------------------------------------------------------------------------------
        FAILED TRANSACTIONS:
        --------------------------------------------------------------------------------
        """

        if errors.isEmpty {
            report += "\nNo failures recorded.\n"
        } else {
            for err in errors {
                report += """

                [\(err.request.rawMethod)] Status: \(err.response?.statusCode ?? 0)
                URL: \(err.request.url.absoluteString)
                Error: \(err.error?.localizedDescription ?? "HTTP \(err.response?.statusCode ?? 0)")
                Latency: \(err.formattedDuration)
                cURL:
                \(err.generateCurl(maskTokens: true))
                --------------------------------------------------------------------------------
                """
            }
        }

        return report.data(using: .utf8)
    }
}


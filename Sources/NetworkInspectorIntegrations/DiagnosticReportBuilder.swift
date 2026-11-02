import Foundation
import NetworkInspectorCore

public enum DiagnosticReportBuilder {

    public static func buildReport(
        for transaction: NetworkTransaction,
        includeCurl: Bool = true
    ) -> String {
        let req = transaction.request
        let res = transaction.response

        var report = """
        =======================================================
        📡 NETWORK TRANSACTION DETAILS
        =======================================================
        ID       : \(transaction.id.uuidString)
        Date     : \(req.timestamp.formatted(date: .abbreviated, time: .standard))
        Source   : \(transaction.clientSource)
        Duration : \(transaction.formattedDuration)

        -------------------------------------------------------
        📨 REQUEST
        -------------------------------------------------------
        Method : \(req.rawMethod)
        URL    : \(req.url.absoluteString)
        Scheme : \(req.scheme)
        Host   : \(req.host)
        Path   : \(req.path)

        HEADERS:
        """

        if req.headers.isEmpty {
            report += "\n(No headers)\n"
        } else {
            for (k, v) in req.headers.sorted(by: { $0.key < $1.key }) {
                report += "\n\(k): \(v)"
            }
            report += "\n"
        }

        if let bodyStr = req.bodyString, !bodyStr.isEmpty {
            report += "\nBODY (\(req.bodySize) bytes):\n\(bodyStr)\n"
        }

        report += """

        -------------------------------------------------------
        📦 RESPONSE
        -------------------------------------------------------
        Status Code : \(res?.statusCode ?? 0) (\(res?.statusDescription ?? "No Response"))
        MIME Type   : \(res?.mimeType ?? "N/A")
        Size        : \(res?.contentLength ?? 0) bytes

        HEADERS:
        """

        if let headers = res?.headers, !headers.isEmpty {
            for (k, v) in headers.sorted(by: { $0.key < $1.key }) {
                report += "\n\(k): \(v)"
            }
            report += "\n"
        } else {
            report += "\n(No response headers)\n"
        }

        if let resBody = res?.bodyString, !resBody.isEmpty {
            report += "\nRESPONSE BODY:\n\(resBody)\n"
        }

        if let err = transaction.error {
            report += """

            -------------------------------------------------------
            ⚠️ ERROR
            -------------------------------------------------------
            Domain      : \(err.domain)
            Code        : \(err.code)
            Description : \(err.localizedDescription)
            Reason      : \(err.failureReason ?? "N/A")
            """
        }

        if includeCurl {
            report += """

            -------------------------------------------------------
            💻 cURL COMMAND (Sanitized)
            -------------------------------------------------------
            \(transaction.generateCurl(maskTokens: true))
            """
        }

        report += "\n=======================================================\n"
        return report
    }
}


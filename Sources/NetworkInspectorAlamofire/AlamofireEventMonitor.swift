import Foundation
import Alamofire
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorPrivacy

public final class AlamofireEventMonitor: EventMonitor, @unchecked Sendable {
    public let queue = DispatchQueue(label: "com.networkinspector.alamofire.monitor", qos: .utility)

    private var transactionMap: [UUID: NetworkTransaction] = [:]
    private var requestStartDates: [UUID: Date] = [:]
    private let lock = NSLock()

    public init() {}

    public func requestDidResume(_ request: Request) {
        let reqID = request.id
        let now = Date()

        lock.lock()
        requestStartDates[reqID] = now
        lock.unlock()

        guard let urlRequest = request.request, let url = urlRequest.url else { return }

        let headers = urlRequest.allHTTPHeaderFields ?? [:]
        let netReq = NetworkRequest(
            id: reqID,
            url: url,
            method: urlRequest.httpMethod ?? "GET",
            headers: headers,
            body: urlRequest.httpBody,
            timestamp: now
        )

        var multipartParts: [MultipartPart]?
        if let contentType = urlRequest.allHTTPHeaderFields?["Content-Type"],
           contentType.contains("multipart/form-data") {
            multipartParts = parseMultipartMetadata(from: urlRequest)
        }

        let transaction = NetworkTransaction(
            id: reqID,
            sessionID: NetworkLogStore.shared.activeSession.id,
            clientSource: "Alamofire",
            request: netReq,
            multipartParts: multipartParts,
            status: .pending
        )

        lock.lock()
        transactionMap[reqID] = transaction
        lock.unlock()

        NetworkLogStore.shared.record(transaction)
    }

    public func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        let reqID = request.id
        let now = Date()

        lock.lock()
        let startDate = requestStartDates[reqID] ?? now
        let transaction = transactionMap[reqID]
        lock.unlock()

        let duration = now.timeIntervalSince(startDate)

        guard var current = transaction ?? makeFallbackTransaction(from: request, now: now) else { return }

        current.duration = duration

        if let httpResponse = response.response {
            var headers: [String: String] = [:]
            for (k, v) in httpResponse.allHeaderFields {
                headers["\(k)"] = "\(v)"
            }

            current.response = NetworkResponse(
                statusCode: httpResponse.statusCode,
                headers: headers,
                body: response.data,
                mimeType: httpResponse.mimeType,
                contentLength: httpResponse.expectedContentLength > 0 ? httpResponse.expectedContentLength : Int64(response.data?.count ?? 0),
                timestamp: now
            )
            current.status = (200...399).contains(httpResponse.statusCode) ? .success : .failed
        }

        if let error = response.error {
            current.error = NetworkError(error: error)
            current.status = error.isExplicitlyCancelledError ? .cancelled : .failed
        }

        if let metrics = response.metrics {
            current.metrics = NetworkTaskMetrics(urlSessionTaskMetrics: metrics)
        }

        lock.lock()
        transactionMap[reqID] = current
        lock.unlock()

        NetworkLogStore.shared.record(current)
    }

    public func requestDidFinish(_ request: Request) {
        let reqID = request.id
        lock.lock()
        requestStartDates.removeValue(forKey: reqID)
        transactionMap.removeValue(forKey: reqID)
        lock.unlock()
    }

    private func makeFallbackTransaction(from request: Request, now: Date) -> NetworkTransaction? {
        guard let urlRequest = request.request, let url = urlRequest.url else { return nil }
        let netReq = NetworkRequest(
            id: request.id,
            url: url,
            method: urlRequest.httpMethod ?? "GET",
            headers: urlRequest.allHTTPHeaderFields ?? [:],
            body: urlRequest.httpBody,
            timestamp: now
        )
        return NetworkTransaction(
            id: request.id,
            sessionID: NetworkLogStore.shared.activeSession.id,
            clientSource: "Alamofire",
            request: netReq,
            status: .pending
        )
    }

    private func parseMultipartMetadata(from request: URLRequest) -> [MultipartPart] {
        guard let stream = request.httpBodyStream ?? (request.httpBody != nil ? InputStream(data: request.httpBody!) : nil) else {
            return []
        }
        _ = stream
        // Basic metadata fallback if body is present
        if let body = request.httpBody {
            return [
                MultipartPart(
                    name: "multipart_payload",
                    filename: nil,
                    mimeType: request.value(forHTTPHeaderField: "Content-Type"),
                    size: Int64(body.count),
                    isFile: false,
                    previewContent: nil
                )
            ]
        }
        return []
    }
}

public enum NetworkInspectorAlamofire {
    public static func makeEventMonitor() -> AlamofireEventMonitor {
        AlamofireEventMonitor()
    }

    public static func makeSession(
        configuration: URLSessionConfiguration = .default,
        additionalEventMonitors: [EventMonitor] = []
    ) -> Session {
        var monitors: [EventMonitor] = [makeEventMonitor()]
        monitors.append(contentsOf: additionalEventMonitors)
        return Session(configuration: configuration, eventMonitors: monitors)
    }
}

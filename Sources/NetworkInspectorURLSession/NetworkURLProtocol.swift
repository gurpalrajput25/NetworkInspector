import Foundation
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorPrivacy

public final class NetworkURLProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "com.networkinspector.urlprotocol.handled"

    private var activeDataTask: URLSessionDataTask?
    private var internalSession: URLSession?
    private var transactionID = UUID()
    private var startDate = Date()
    private var accumulatedData = Data()
    private var capturedResponse: HTTPURLResponse?

    public override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url,
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return false
        }

        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }

        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    public override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "NetworkInspector", code: -1))
            return
        }

        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        let interceptedRequest = mutableRequest as URLRequest

        self.startDate = Date()
        self.transactionID = UUID()

        // Capture initial request
        if let url = interceptedRequest.url {
            let capturedHeaders = interceptedRequest.allHTTPHeaderFields ?? [:]
            let req = NetworkRequest(
                id: transactionID,
                url: url,
                method: interceptedRequest.httpMethod ?? "GET",
                headers: capturedHeaders,
                rawHeaders: capturedHeaders,
                body: interceptedRequest.httpBody,
                rawBody: interceptedRequest.httpBody,
                timestamp: startDate
            )
            let transaction = NetworkTransaction(
                id: transactionID,
                sessionID: NetworkLogStore.shared.activeSession.id,
                clientSource: "URLSession",
                request: req,
                status: .pending
            )
            NetworkLogStore.shared.record(transaction)
        }

        let config = URLSessionConfiguration.ephemeral
        self.internalSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.activeDataTask = internalSession?.dataTask(with: interceptedRequest)
        self.activeDataTask?.resume()
    }

    public override func stopLoading() {
        activeDataTask?.cancel()
        activeDataTask = nil
        internalSession?.invalidateAndCancel()
        internalSession = nil
    }
}

// MARK: - URLSessionDataDelegate
extension NetworkURLProtocol: URLSessionDataDelegate {

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let httpResponse = response as? HTTPURLResponse {
            self.capturedResponse = httpResponse
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        accumulatedData.append(data)
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let duration = Date().timeIntervalSince(startDate)

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)

            if var existing = NetworkLogStore.shared.transaction(with: transactionID) {
                existing.duration = duration
                existing.error = NetworkError(error: error)
                existing.status = (error as NSError).code == NSURLErrorCancelled ? .cancelled : .failed
                NetworkLogStore.shared.record(existing)
            }
        } else {
            client?.urlProtocolDidFinishLoading(self)

            if var existing = NetworkLogStore.shared.transaction(with: transactionID) {
                existing.duration = duration
                if let httpResponse = capturedResponse {
                    var headers: [String: String] = [:]
                    for (k, v) in httpResponse.allHeaderFields {
                        headers["\(k)"] = "\(v)"
                    }
                    existing.response = NetworkResponse(
                        statusCode: httpResponse.statusCode,
                        headers: headers,
                        body: accumulatedData.isEmpty ? nil : accumulatedData,
                        mimeType: httpResponse.mimeType,
                        contentLength: httpResponse.expectedContentLength > 0 ? httpResponse.expectedContentLength : Int64(accumulatedData.count),
                        timestamp: Date()
                    )
                    existing.status = (200...399).contains(httpResponse.statusCode) ? .success : .failed

                    if existing.userDetails == nil, !accumulatedData.isEmpty {
                        existing.userDetails = JWTDecoder.extractFromResponseBody(accumulatedData)
                    }
                }
                NetworkLogStore.shared.record(existing)
            }
        }

        internalSession?.finishTasksAndInvalidate()
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        if var existing = NetworkLogStore.shared.transaction(with: transactionID) {
            existing.metrics = NetworkTaskMetrics(urlSessionTaskMetrics: metrics)
            NetworkLogStore.shared.record(existing)
        }
    }
}


import Foundation

public struct NetworkTaskMetrics: Codable, Sendable {
    public let dnsDuration: TimeInterval?
    public let connectDuration: TimeInterval?
    public let tlsDuration: TimeInterval?
    public let requestDuration: TimeInterval?
    public let waitDuration: TimeInterval?
    public let responseDuration: TimeInterval?
    public let totalDuration: TimeInterval?
    public let isReusedConnection: Bool
    public let protocolName: String?

    public init(
        dnsDuration: TimeInterval? = nil,
        connectDuration: TimeInterval? = nil,
        tlsDuration: TimeInterval? = nil,
        requestDuration: TimeInterval? = nil,
        waitDuration: TimeInterval? = nil,
        responseDuration: TimeInterval? = nil,
        totalDuration: TimeInterval? = nil,
        isReusedConnection: Bool = false,
        protocolName: String? = nil
    ) {
        self.dnsDuration = dnsDuration
        self.connectDuration = connectDuration
        self.tlsDuration = tlsDuration
        self.requestDuration = requestDuration
        self.waitDuration = waitDuration
        self.responseDuration = responseDuration
        self.totalDuration = totalDuration
        self.isReusedConnection = isReusedConnection
        self.protocolName = protocolName
    }

    @available(iOS 10.0, macOS 10.12, *)
    public init(urlSessionTaskMetrics metrics: URLSessionTaskMetrics) {
        guard let transactionMetrics = metrics.transactionMetrics.last else {
            self.init(totalDuration: metrics.taskInterval.duration)
            return
        }

        func duration(from start: Date?, to end: Date?) -> TimeInterval? {
            guard let s = start, let e = end else { return nil }
            let d = e.timeIntervalSince(s)
            return d >= 0 ? d : nil
        }

        let dns = duration(
            from: transactionMetrics.domainLookupStartDate,
            to: transactionMetrics.domainLookupEndDate
        )
        let connect = duration(
            from: transactionMetrics.connectStartDate,
            to: transactionMetrics.connectEndDate
        )
        let tls = duration(
            from: transactionMetrics.secureConnectionStartDate,
            to: transactionMetrics.secureConnectionEndDate
        )
        let request = duration(
            from: transactionMetrics.requestStartDate,
            to: transactionMetrics.requestEndDate
        )
        let wait = duration(
            from: transactionMetrics.requestEndDate,
            to: transactionMetrics.responseStartDate
        )
        let response = duration(
            from: transactionMetrics.responseStartDate,
            to: transactionMetrics.responseEndDate
        )

        self.init(
            dnsDuration: dns,
            connectDuration: connect,
            tlsDuration: tls,
            requestDuration: request,
            waitDuration: wait,
            responseDuration: response,
            totalDuration: metrics.taskInterval.duration,
            isReusedConnection: transactionMetrics.isReusedConnection,
            protocolName: transactionMetrics.networkProtocolName
        )
    }
}

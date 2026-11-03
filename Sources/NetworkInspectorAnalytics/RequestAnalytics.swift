import Foundation
import NetworkInspectorCore

public enum PerformanceTier: String, Codable, Sendable {
    case blazingFast = "Blazing Fast (< 150ms)"
    case fast = "Fast (150ms - 500ms)"
    case normal = "Moderate (500ms - 1.5s)"
    case slow = "Slow (1.5s - 3s)"
    case critical = "Critical Latency (> 3s)"

    public var badgeColorName: String {
        switch self {
        case .blazingFast, .fast: return "green"
        case .normal: return "blue"
        case .slow: return "orange"
        case .critical: return "red"
        }
    }
}

public struct TimingPhase: Identifiable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let duration: TimeInterval
    public let percentageOfTotal: Double
    public let colorName: String

    public var formattedDuration: String {
        if duration < 0.001 {
            return "< 1 ms"
        } else if duration < 1.0 {
            return String(format: "%.1f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }

    public var formattedPercentage: String {
        String(format: "%.1f%%", percentageOfTotal * 100)
    }

    public init(name: String, duration: TimeInterval, percentageOfTotal: Double, colorName: String) {
        self.name = name
        self.duration = duration
        self.percentageOfTotal = percentageOfTotal
        self.colorName = colorName
    }
}

public struct RequestAnalytics: Codable, Sendable {
    public let transactionID: UUID
    public let totalDuration: TimeInterval
    public let dnsDuration: TimeInterval?
    public let connectDuration: TimeInterval?
    public let tlsDuration: TimeInterval?
    public let requestDuration: TimeInterval?
    public let waitDuration: TimeInterval? // TTFB
    public let responseDuration: TimeInterval?
    public let phases: [TimingPhase]

    // Data Stats
    public let requestHeadersBytes: Int
    public let requestBodyBytes: Int
    public let totalBytesSent: Int

    public let responseHeadersBytes: Int
    public let responseBodyBytes: Int64
    public let totalBytesReceived: Int64

    public let totalDataTransferred: Int64
    public let throughputBytesPerSecond: Double?
    public let formattedThroughput: String?

    // Network & Transport
    public let networkProtocol: String
    public let isReusedConnection: Bool
    public let clientSource: String

    // Compression & Caching
    public let contentEncoding: String
    public let isCompressed: Bool
    public let estimatedUncompressedBytes: Int64?
    public let cacheControlHeader: String?
    public let eTag: String?
    public let isCacheable: Bool

    // Performance Benchmark
    public let performanceTier: PerformanceTier
    public let hostComparison: String?

    public init(
        transactionID: UUID,
        totalDuration: TimeInterval,
        dnsDuration: TimeInterval?,
        connectDuration: TimeInterval?,
        tlsDuration: TimeInterval?,
        requestDuration: TimeInterval?,
        waitDuration: TimeInterval?,
        responseDuration: TimeInterval?,
        phases: [TimingPhase],
        requestHeadersBytes: Int,
        requestBodyBytes: Int,
        totalBytesSent: Int,
        responseHeadersBytes: Int,
        responseBodyBytes: Int64,
        totalBytesReceived: Int64,
        totalDataTransferred: Int64,
        throughputBytesPerSecond: Double?,
        formattedThroughput: String?,
        networkProtocol: String,
        isReusedConnection: Bool,
        clientSource: String,
        contentEncoding: String,
        isCompressed: Bool,
        estimatedUncompressedBytes: Int64?,
        cacheControlHeader: String?,
        eTag: String?,
        isCacheable: Bool,
        performanceTier: PerformanceTier,
        hostComparison: String?
    ) {
        self.transactionID = transactionID
        self.totalDuration = totalDuration
        self.dnsDuration = dnsDuration
        self.connectDuration = connectDuration
        self.tlsDuration = tlsDuration
        self.requestDuration = requestDuration
        self.waitDuration = waitDuration
        self.responseDuration = responseDuration
        self.phases = phases
        self.requestHeadersBytes = requestHeadersBytes
        self.requestBodyBytes = requestBodyBytes
        self.totalBytesSent = totalBytesSent
        self.responseHeadersBytes = responseHeadersBytes
        self.responseBodyBytes = responseBodyBytes
        self.totalBytesReceived = totalBytesReceived
        self.totalDataTransferred = totalDataTransferred
        self.throughputBytesPerSecond = throughputBytesPerSecond
        self.formattedThroughput = formattedThroughput
        self.networkProtocol = networkProtocol
        self.isReusedConnection = isReusedConnection
        self.clientSource = clientSource
        self.contentEncoding = contentEncoding
        self.isCompressed = isCompressed
        self.estimatedUncompressedBytes = estimatedUncompressedBytes
        self.cacheControlHeader = cacheControlHeader
        self.eTag = eTag
        self.isCacheable = isCacheable
        self.performanceTier = performanceTier
        self.hostComparison = hostComparison
    }
}

// MARK: - Builder

public enum RequestAnalyticsBuilder {

    public static func build(for transaction: NetworkTransaction, hostAverageDuration: TimeInterval? = nil) -> RequestAnalytics {
        let total = transaction.duration ?? transaction.metrics?.totalDuration ?? 0.001
        let metrics = transaction.metrics

        let dns = metrics?.dnsDuration
        let connect = metrics?.connectDuration
        let tls = metrics?.tlsDuration
        let reqDur = metrics?.requestDuration
        let wait = metrics?.waitDuration
        let resDur = metrics?.responseDuration

        // Compute phases
        var phases: [TimingPhase] = []
        let safeTotal = max(total, 0.0001)

        if let d = dns, d > 0 {
            phases.append(TimingPhase(name: "DNS Lookup", duration: d, percentageOfTotal: min(1.0, d / safeTotal), colorName: "purple"))
        }
        if let c = connect, c > 0 {
            phases.append(TimingPhase(name: "TCP Connect", duration: c, percentageOfTotal: min(1.0, c / safeTotal), colorName: "blue"))
        }
        if let s = tls, s > 0 {
            phases.append(TimingPhase(name: "TLS Handshake", duration: s, percentageOfTotal: min(1.0, s / safeTotal), colorName: "indigo"))
        }
        if let r = reqDur, r > 0 {
            phases.append(TimingPhase(name: "Request Send", duration: r, percentageOfTotal: min(1.0, r / safeTotal), colorName: "cyan"))
        }
        if let w = wait, w > 0 {
            phases.append(TimingPhase(name: "Server Wait (TTFB)", duration: w, percentageOfTotal: min(1.0, w / safeTotal), colorName: "orange"))
        }
        if let rp = resDur, rp > 0 {
            phases.append(TimingPhase(name: "Download", duration: rp, percentageOfTotal: min(1.0, rp / safeTotal), colorName: "green"))
        }

        // If no detailed breakdown from URLSessionTaskMetrics, provide a single execution phase
        if phases.isEmpty {
            phases.append(TimingPhase(name: "Round-Trip Duration", duration: safeTotal, percentageOfTotal: 1.0, colorName: "blue"))
        }

        // Request size
        let reqHeaders = transaction.request.rawHeaders.isEmpty ? transaction.request.headers : transaction.request.rawHeaders
        let reqHeadersBytes = reqHeaders.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count + 4 }
        let reqBodyBytes = transaction.request.bodySize
        let totalSent = reqHeadersBytes + reqBodyBytes

        // Response size
        let resHeaders = transaction.response?.headers ?? [:]
        let resHeadersBytes = resHeaders.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count + 4 }
        let resBodyBytes = transaction.response?.contentLength ?? Int64(transaction.response?.body?.count ?? 0)
        let totalReceived = Int64(resHeadersBytes) + resBodyBytes
        let totalTransferred = Int64(totalSent) + totalReceived

        // Throughput
        var throughput: Double? = nil
        var formattedThroughput: String? = nil
        let downloadTime = resDur ?? (total > 0 ? total : nil)
        if let dt = downloadTime, dt > 0.01, resBodyBytes > 0 {
            let bytesPerSec = Double(resBodyBytes) / dt
            throughput = bytesPerSec
            if bytesPerSec > 1_000_000 {
                formattedThroughput = String(format: "%.2f MB/s", bytesPerSec / 1_000_000)
            } else {
                formattedThroughput = String(format: "%.1f KB/s", bytesPerSec / 1_000)
            }
        }

        // Compression
        let encoding = resHeaders["Content-Encoding"] ?? resHeaders["content-encoding"] ?? "identity"
        let isCompressed = ["gzip", "br", "deflate"].contains(encoding.lowercased())
        var uncompressedBytes: Int64? = nil
        if isCompressed && resBodyBytes > 0 {
            // Rough estimation of uncompressed JSON size (typically 3.5x to 4x of gzip/brotli)
            uncompressedBytes = Int64(Double(resBodyBytes) * 3.8)
        }

        // Caching
        let cacheControl = resHeaders["Cache-Control"] ?? resHeaders["cache-control"]
        let eTag = resHeaders["ETag"] ?? resHeaders["etag"]
        let isCacheable = cacheControl != nil && !cacheControl!.lowercased().contains("no-store")

        // Protocol & Connection
        let proto = metrics?.protocolName ?? (transaction.request.scheme == "https" ? "h2 (HTTP/2)" : "http/1.1")
        let reused = metrics?.isReusedConnection ?? false

        // Performance Tier
        let tier: PerformanceTier
        switch total {
        case ..<0.15: tier = .blazingFast
        case 0.15..<0.5: tier = .fast
        case 0.5..<1.5: tier = .normal
        case 1.5..<3.0: tier = .slow
        default: tier = .critical
        }

        // Host comparison
        var comparison: String? = nil
        if let hostAvg = hostAverageDuration, hostAvg > 0 {
            let diff = ((total - hostAvg) / hostAvg) * 100.0
            if abs(diff) < 5 {
                comparison = "Similar to host average (\(String(format: "%.0f ms", hostAvg * 1000)))"
            } else if diff < 0 {
                comparison = String(format: "%.0f%% faster than host average", abs(diff))
            } else {
                comparison = String(format: "%.0f%% slower than host average", diff)
            }
        }

        return RequestAnalytics(
            transactionID: transaction.id,
            totalDuration: total,
            dnsDuration: dns,
            connectDuration: connect,
            tlsDuration: tls,
            requestDuration: reqDur,
            waitDuration: wait,
            responseDuration: resDur,
            phases: phases,
            requestHeadersBytes: reqHeadersBytes,
            requestBodyBytes: reqBodyBytes,
            totalBytesSent: totalSent,
            responseHeadersBytes: resHeadersBytes,
            responseBodyBytes: resBodyBytes,
            totalBytesReceived: totalReceived,
            totalDataTransferred: totalTransferred,
            throughputBytesPerSecond: throughput,
            formattedThroughput: formattedThroughput,
            networkProtocol: proto,
            isReusedConnection: reused,
            clientSource: transaction.clientSource,
            contentEncoding: encoding,
            isCompressed: isCompressed,
            estimatedUncompressedBytes: uncompressedBytes,
            cacheControlHeader: cacheControl,
            eTag: eTag,
            isCacheable: isCacheable,
            performanceTier: tier,
            hostComparison: comparison
        )
    }
}


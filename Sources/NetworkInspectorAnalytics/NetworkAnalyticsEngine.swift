import Foundation
import NetworkInspectorCore

public enum NetworkAnalyticsEngine {

    public static func computeMetrics(from transactions: [NetworkTransaction]) -> NetworkPerformanceMetrics {
        guard !transactions.isEmpty else {
            return NetworkPerformanceMetrics()
        }

        let totalRequests = transactions.count
        let durations = transactions.compactMap { $0.duration }.sorted()

        let totalDuration = durations.reduce(0, +)
        let averageResponseTime = durations.isEmpty ? 0 : totalDuration / Double(durations.count)
        let maxResponseTime = durations.last ?? 0

        func percentile(_ p: Double) -> TimeInterval {
            guard !durations.isEmpty else { return 0 }
            let idx = min(Int(Double(durations.count) * p), durations.count - 1)
            return durations[idx]
        }

        let medianResponseTime = percentile(0.50)
        let p75ResponseTime = percentile(0.75)
        let p90ResponseTime = percentile(0.90)
        let p95ResponseTime = percentile(0.95)
        let p99ResponseTime = percentile(0.99)

        let failedCount = transactions.filter {
            $0.error != nil || ($0.response?.statusCode ?? 200) >= 400 || $0.status == .failed
        }.count
        let failurePercentage = Double(failedCount) / Double(totalRequests) * 100.0

        let totalUploaded = transactions.reduce(Int64(0)) { $0 + Int64($1.request.bodySize) }
        let totalDownloaded = transactions.reduce(Int64(0)) { $0 + ($1.response?.contentLength ?? 0) }
        let averageResponseSize = totalRequests > 0 ? totalDownloaded / Int64(totalRequests) : 0

        // Requests per second
        var rps: Double = 0
        if let first = transactions.map({ $0.request.timestamp }).min(),
           let last = transactions.map({ $0.response?.timestamp ?? $0.request.timestamp }).max() {
            let interval = last.timeIntervalSince(first)
            if interval > 1.0 {
                rps = Double(totalRequests) / interval
            } else {
                rps = Double(totalRequests)
            }
        }

        return NetworkPerformanceMetrics(
            totalRequests: totalRequests,
            averageResponseTime: averageResponseTime,
            medianResponseTime: medianResponseTime,
            p75ResponseTime: p75ResponseTime,
            p90ResponseTime: p90ResponseTime,
            p95ResponseTime: p95ResponseTime,
            p99ResponseTime: p99ResponseTime,
            maxResponseTime: maxResponseTime,
            requestsPerSecond: rps,
            failurePercentage: failurePercentage,
            averageResponseSize: averageResponseSize,
            totalUploadedBytes: totalUploaded,
            totalDownloadedBytes: totalDownloaded
        )
    }

    public static func computeStatistics(from transactions: [NetworkTransaction]) -> NetworkStatistics {
        // Group by host
        var hostMap: [String: (count: Int, errorCount: Int, durations: [TimeInterval])] = [:]
        var methodCounts: [String: Int] = [:]
        var statusCounts: [String: Int] = [:]
        var errorMap: [String: Int] = [:]

        for t in transactions {
            let host = t.request.host.isEmpty ? "unknown" : t.request.host
            let isErr = t.error != nil || (t.response?.statusCode ?? 200) >= 400
            let duration = t.duration ?? 0

            var current = hostMap[host] ?? (0, 0, [])
            current.count += 1
            if isErr { current.errorCount += 1 }
            current.durations.append(duration)
            hostMap[host] = current

            let m = t.request.rawMethod
            methodCounts[m, default: 0] += 1

            let s: String
            if let code = t.response?.statusCode {
                s = "\(code / 100)xx"
            } else {
                s = "Error"
            }
            statusCounts[s, default: 0] += 1

            if let err = t.error {
                errorMap[err.localizedDescription, default: 0] += 1
            } else if let code = t.response?.statusCode, code >= 400 {
                let desc = "HTTP \(code) (\(t.response?.statusDescription ?? "Error"))"
                errorMap[desc, default: 0] += 1
            }
        }

        let hostBreakdown: [HostStatistics] = hostMap.map { host, val in
            let avg = val.durations.isEmpty ? 0 : val.durations.reduce(0, +) / Double(val.durations.count)
            return HostStatistics(
                host: host,
                count: val.count,
                errorCount: val.errorCount,
                averageDuration: avg
            )
        }.sorted { $0.count > $1.count }

        let topErrors = errorMap.map { (error: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        return NetworkStatistics(
            hostBreakdown: hostBreakdown,
            methodCounts: methodCounts,
            statusCounts: statusCounts,
            topErrors: topErrors
        )
    }
}


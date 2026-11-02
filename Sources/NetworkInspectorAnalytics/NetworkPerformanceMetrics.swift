import Foundation
import NetworkInspectorCore

public struct NetworkPerformanceMetrics: Sendable {
    public let totalRequests: Int
    public let averageResponseTime: TimeInterval
    public let medianResponseTime: TimeInterval
    public let p75ResponseTime: TimeInterval
    public let p90ResponseTime: TimeInterval
    public let p95ResponseTime: TimeInterval
    public let p99ResponseTime: TimeInterval
    public let maxResponseTime: TimeInterval
    public let requestsPerSecond: Double
    public let failurePercentage: Double
    public let averageResponseSize: Int64
    public let totalUploadedBytes: Int64
    public let totalDownloadedBytes: Int64

    public init(
        totalRequests: Int = 0,
        averageResponseTime: TimeInterval = 0,
        medianResponseTime: TimeInterval = 0,
        p75ResponseTime: TimeInterval = 0,
        p90ResponseTime: TimeInterval = 0,
        p95ResponseTime: TimeInterval = 0,
        p99ResponseTime: TimeInterval = 0,
        maxResponseTime: TimeInterval = 0,
        requestsPerSecond: Double = 0,
        failurePercentage: Double = 0,
        averageResponseSize: Int64 = 0,
        totalUploadedBytes: Int64 = 0,
        totalDownloadedBytes: Int64 = 0
    ) {
        self.totalRequests = totalRequests
        self.averageResponseTime = averageResponseTime
        self.medianResponseTime = medianResponseTime
        self.p75ResponseTime = p75ResponseTime
        self.p90ResponseTime = p90ResponseTime
        self.p95ResponseTime = p95ResponseTime
        self.p99ResponseTime = p99ResponseTime
        self.maxResponseTime = maxResponseTime
        self.requestsPerSecond = requestsPerSecond
        self.failurePercentage = failurePercentage
        self.averageResponseSize = averageResponseSize
        self.totalUploadedBytes = totalUploadedBytes
        self.totalDownloadedBytes = totalDownloadedBytes
    }
}

public struct HostStatistics: Identifiable, Sendable {
    public var id: String { host }
    public let host: String
    public let count: Int
    public let errorCount: Int
    public let averageDuration: TimeInterval
}

public struct NetworkStatistics: Sendable {
    public let hostBreakdown: [HostStatistics]
    public let methodCounts: [String: Int]
    public let statusCounts: [String: Int]
    public let topErrors: [(error: String, count: Int)]

    public init(
        hostBreakdown: [HostStatistics] = [],
        methodCounts: [String: Int] = [:],
        statusCounts: [String: Int] = [:],
        topErrors: [(error: String, count: Int)] = []
    ) {
        self.hostBreakdown = hostBreakdown
        self.methodCounts = methodCounts
        self.statusCounts = statusCounts
        self.topErrors = topErrors
    }
}


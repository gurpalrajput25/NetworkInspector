import Foundation
import NetworkInspectorCore

public enum HealthStatus: String, Sendable {
    case optimal = "Optimal"
    case good = "Good"
    case degraded = "Degraded"
    case critical = "Critical"

    public var scoreRange: String {
        switch self {
        case .optimal: return "90 - 100"
        case .good: return "75 - 89"
        case .degraded: return "50 - 74"
        case .critical: return "0 - 49"
        }
    }
}

public struct NetworkHealthReport: Sendable {
    public let score: Int
    public let status: HealthStatus
    public let summary: String
    public let suggestions: [String]
}

public enum NetworkHealthCalculator {

    public static func evaluate(transactions: [NetworkTransaction]) -> NetworkHealthReport {
        guard !transactions.isEmpty else {
            return NetworkHealthReport(
                score: 100,
                status: .optimal,
                summary: "No network requests recorded yet.",
                suggestions: ["Start making network requests to evaluate health."]
            )
        }

        var score = 100
        var suggestions: [String] = []

        let total = transactions.count
        let errors = transactions.filter {
            $0.error != nil || ($0.response?.statusCode ?? 200) >= 400
        }
        let failureRate = Double(errors.count) / Double(total)

        // Deduct for failure rate
        if failureRate > 0.3 {
            score -= 40
            suggestions.append("High failure rate (\(Int(failureRate * 100))%). Check backend health or API error responses.")
        } else if failureRate > 0.1 {
            score -= 20
            suggestions.append("Moderate failure rate (\(Int(failureRate * 100))%). Review client or server errors.")
        } else if failureRate > 0 {
            score -= 5
        }

        // Deduct for latency
        let durations = transactions.compactMap { $0.duration }.sorted()
        if !durations.isEmpty {
            let p90Index = min(Int(Double(durations.count) * 0.90), durations.count - 1)
            let p90 = durations[p90Index]

            if p90 > 3.0 {
                score -= 25
                suggestions.append("P90 latency is high (\(String(format: "%.2f s", p90))). Consider caching or optimizing API endpoints.")
            } else if p90 > 1.5 {
                score -= 10
                suggestions.append("P90 latency is above 1.5s (\(String(format: "%.2f s", p90))).")
            }
        }

        // Deduct for huge payload sizes
        let largeResponses = transactions.filter { ($0.response?.contentLength ?? 0) > 2_000_000 }
        if !largeResponses.isEmpty {
            score -= 10
            suggestions.append("\(largeResponses.count) response(s) exceeded 2 MB. Implement pagination or compression.")
        }

        score = max(0, min(100, score))

        let status: HealthStatus
        switch score {
        case 90...100: status = .optimal
        case 75...89:  status = .good
        case 50...74:  status = .degraded
        default:       status = .critical
        }

        let summary = "\(status.rawValue) performance with \(total) requests captured."
        return NetworkHealthReport(score: score, status: status, summary: summary, suggestions: suggestions)
    }
}


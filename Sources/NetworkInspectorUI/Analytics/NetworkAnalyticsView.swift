import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorAnalytics

public struct NetworkAnalyticsView: View {
    @ObservedObject var logStore: NetworkLogStore = .shared

    public init() {}

    private var metrics: NetworkPerformanceMetrics {
        NetworkAnalyticsEngine.computeMetrics(from: logStore.transactions)
    }

    private var stats: NetworkStatistics {
        NetworkAnalyticsEngine.computeStatistics(from: logStore.transactions)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Latency Percentiles Grid
                percentilesSection

                // Host Breakdown
                hostBreakdownSection

                // Method Distribution
                methodsSection

                // Status Distribution
                statusCodesSection
            }
            .padding()
        }
        .navigationTitle("Performance Analytics")
        .inspectorNavigationTitleDisplayModeInline()
    }

    private var percentilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latency Percentiles")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                percentileCard(title: "Median", value: formatDuration(metrics.medianResponseTime))
                percentileCard(title: "P75", value: formatDuration(metrics.p75ResponseTime))
                percentileCard(title: "P90", value: formatDuration(metrics.p90ResponseTime))
                percentileCard(title: "P95", value: formatDuration(metrics.p95ResponseTime))
                percentileCard(title: "P99", value: formatDuration(metrics.p99ResponseTime))
                percentileCard(title: "Max", value: formatDuration(metrics.maxResponseTime))
            }
        }
        .padding()
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func percentileCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.inspectorCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var hostBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Hosts")
                .font(.headline)

            if stats.hostBreakdown.isEmpty {
                Text("No host data available.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(stats.hostBreakdown.prefix(8)) { hostStat in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hostStat.host)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                Text("\(hostStat.count) requests • \(hostStat.errorCount) errors")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(formatDuration(hostStat.averageDuration))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.inspectorCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var methodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HTTP Methods")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(stats.methodCounts.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                    VStack(spacing: 4) {
                        MethodBadgeView(method: item.key)
                        Text("\(item.value)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.inspectorCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusCodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Breakdown")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(stats.statusCounts.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                    VStack(spacing: 4) {
                        Text(item.key)
                            .font(.caption.bold())
                            .foregroundColor(statusColor(item.key))
                        Text("\(item.value)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.inspectorCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        if d < 1.0 {
            return String(format: "%.0f ms", d * 1000)
        } else {
            return String(format: "%.2f s", d)
        }
    }

    private func statusColor(_ key: String) -> Color {
        if key.starts(with: "2") { return .green }
        if key.starts(with: "3") { return .blue }
        if key.starts(with: "4") { return .orange }
        if key.starts(with: "5") { return .red }
        return .red
    }
}
